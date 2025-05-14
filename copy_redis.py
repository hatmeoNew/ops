import redis
from sshtunnel import SSHTunnelForwarder

# --- 配置源 Redis (例如：你运行此脚本的本地机器) ---
SRC_REDIS_HOST = '127.0.0.1'
SRC_REDIS_PORT = 6379
SRC_REDIS_DB = 20  # 要复制的源数据库编号
SRC_REDIS_PASSWORD = ''  # 如果源 Redis 有密码，请填写

# --- 配置目标 Redis (位于远程 SSH 服务器上) ---
# 这些是远程服务器上 Redis 的连接信息 (从远程服务器自身看)
REMOTE_TARGET_REDIS_HOST_ON_SSH_SERVER = '127.0.0.1'  # 通常 Redis 在其服务器上监听 localhost
REMOTE_TARGET_REDIS_PORT_ON_SSH_SERVER = 6379
TARGET_REDIS_DB = 20  # 要复制到的目标数据库编号
TARGET_REDIS_PASSWORD = ''  # 如果目标 Redis 有密码，请填写

# --- 配置 SSH 隧道 ---
SSH_HOST = '172.235.206.91'  # 目标 Redis 所在的服务器 IP 或域名
SSH_PORT = 22  # SSH 端口
SSH_USER = 'root'  # SSH登录用户名，例如 'root' 或其他有权限的用户
SSH_KEY = '/root/.ssh/id_rsa'  # SSH 私钥文件的绝对路径 (确保此脚本有权限读取)
# 如果使用密码登录SSH，可以将 ssh_pkey=SSH_KEY 替换为 ssh_password='YOUR_SSH_PASSWORD'
# 但强烈建议使用密钥进行身份验证

# 1. 连接到源 Redis
try:
    src_redis = redis.Redis(
        host=SRC_REDIS_HOST,
        port=SRC_REDIS_PORT,
        db=SRC_REDIS_DB,
        password=SRC_REDIS_PASSWORD,
        decode_responses=False  # 保持为 False 以便复制原始字节数据
    )
    src_redis.ping()
    print(f"成功连接到源 Redis: {SRC_REDIS_HOST}:{SRC_REDIS_PORT}, DB: {SRC_REDIS_DB}")
except redis.exceptions.ConnectionError as e:
    print(f"连接源 Redis 失败: {e}")
    exit(1)
except Exception as e:
    print(f"连接源 Redis 时发生未知错误: {e}")
    exit(1)

# 2. 建立 SSH 隧道并连接到目标 Redis
try:
    print(f"正在建立到 {SSH_HOST} 的 SSH 隧道...")
    with SSHTunnelForwarder(
        (SSH_HOST, SSH_PORT),
        ssh_username=SSH_USER,
        ssh_pkey=SSH_KEY,
        # 将本地端口转发到远程服务器上的目标 Redis 服务
        remote_bind_address=(REMOTE_TARGET_REDIS_HOST_ON_SSH_SERVER, REMOTE_TARGET_REDIS_PORT_ON_SSH_SERVER)
    ) as tunnel:
        print(f"SSH 隧道已建立。本地绑定端口 (用于连接目标Redis): {tunnel.local_bind_port}")

        target_redis = redis.Redis(
            host='127.0.0.1',  # 通过隧道的本地端连接
            port=tunnel.local_bind_port,
            db=TARGET_REDIS_DB,
            password=TARGET_REDIS_PASSWORD,
            decode_responses=False # 保持为 False
        )
        target_redis.ping()
        print(f"通过 SSH 隧道成功连接到目标 Redis ({SSH_HOST} 上的 Redis), DB: {TARGET_REDIS_DB}")

        # 定义数据同步函数
        def sync_redis_data(src, target):
            # 可选：在复制前清空目标数据库
            # confirm_flush = input(f"警告：是否要清空目标服务器 {SSH_HOST} 上的数据库 DB {TARGET_REDIS_DB}？(yes/no): ")
            # if confirm_flush.lower() == 'yes':
            #     target.flushdb()
            #     print(f"目标数据库 DB {TARGET_REDIS_DB} 已清空。")
            # else:
            #     print("未清空目标数据库。现有键可能会被覆盖或追加。")


            keys_copied_count = 0
            keys_failed_count = 0
            print("\n开始数据同步...")

            # 使用 pipeline 提高效率
            src_pipe = src.pipeline()
            target_pipe = target.pipeline()

            all_keys = list(src.keys('*')) # 获取所有键，转换为列表以避免迭代器问题
            total_keys = len(all_keys)
            print(f"共找到 {total_keys} 个键需要同步。")

            for i, key in enumerate(all_keys):
                key_type = src.type(key)
                ttl = src.ttl(key)

                try:
                    # 对于集合类型（list, set, hash, zset），先删除目标中的同名键，确保是完整复制而非追加
                    if key_type in [b'list', b'hash', b'set', b'zset']:
                        target.delete(key)

                    if key_type == b'string':
                        value = src.get(key)
                        target_pipe.set(key, value)
                    elif key_type == b'hash':
                        hash_data = src.hgetall(key)
                        if hash_data:
                            target_pipe.hmset(key, hash_data)
                    elif key_type == b'list':
                        list_data = src.lrange(key, 0, -1)
                        if list_data:
                            target_pipe.rpush(key, *list_data)
                    elif key_type == b'set':
                        set_data = src.smembers(key)
                        if set_data:
                            target_pipe.sadd(key, *set_data)
                    elif key_type == b'zset':
                        zset_data_tuples = src.zrange(key, 0, -1, withscores=True)
                        if zset_data_tuples:
                            mapping = {member: score for member, score in zset_data_tuples}
                            target_pipe.zadd(key, mapping)
                    # Redis Streams (b'stream') 复制较为复杂，此处暂不处理
                    # elif key_type == b'stream':
                    #     print(f"跳过 Stream类型的键: {key.decode('utf-8', 'ignore')} (需要手动或特定逻辑处理)")
                    #     keys_failed_count += 1
                    #     continue
                    else:
                        print(f"不支持的键类型 {key_type.decode('utf-8', 'ignore')} 对于键 {key.decode('utf-8', 'ignore')}。已跳过。")
                        keys_failed_count += 1
                        continue

                    # 设置 TTL
                    if ttl is not None and ttl > 0:
                        target_pipe.expire(key, ttl)
                    elif ttl == -1: # 键存在但没有关联的过期时间
                        target_pipe.persist(key)
                    
                    keys_copied_count += 1
                    if (i + 1) % 100 == 0 or (i + 1) == total_keys: # 每100个或最后一个键时执行pipeline并打印进度
                        target_pipe.execute()
                        print(f"已处理 {i + 1}/{total_keys} 个键...")
                        target_pipe = target.pipeline() # 重置 pipeline

                except Exception as e_key:
                    print(f"复制键 {key.decode('utf-8', 'ignore')} (类型 {key_type.decode('utf-8', 'ignore')}) 时出错: {e_key}")
                    keys_failed_count += 1
            
            if target_pipe.command_stack: #确保执行最后的pipeline
                target_pipe.execute()

            print(f"\n数据同步完成。")
            print(f"成功复制: {keys_copied_count} 个键。")
            print(f"失败/跳过: {keys_failed_count} 个键。")

        # 执行同步
        sync_redis_data(src_redis, target_redis)

except SSHTunnelForwarder.BaseSSHTunnelForwarderError as e:
    print(f"SSH 隧道错误: {e}")
    print("请检查 SSH_HOST, SSH_PORT, SSH_USER, SSH_KEY 配置以及网络连接。")
    exit(1)
except redis.exceptions.ConnectionError as e:
    print(f"通过 SSH 隧道连接目标 Redis 失败: {e}")
    exit(1)
except Exception as e:
    print(f"发生未知错误: {e}")
    exit(1)

print("\n脚本执行完毕。")