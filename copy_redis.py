import redis
from sshtunnel import SSHTunnelForwarder

# Source Redis connection details
SRC_REDIS_HOST = '127.0.0.1'
SRC_REDIS_PORT = 6379
SRC_REDIS_DB = 21
SRC_REDIS_PASSWORD = ''

# Target Redis connection details
TARGET_REDIS_HOST = '127.0.0.1'
TARGET_REDIS_PORT = 6379
TARGET_REDIS_DB = 50
TARGET_REDIS_PASSWORD = ''

# SSH proxy details
SSH_HOST = '45.79.79.208'
SSH_PORT = 22
SSH_USER = 'root'
SSH_KEY = '/root/.ssh/id_rsa'

# Create SSH tunnel
with SSHTunnelForwarder(
    (SSH_HOST, SSH_PORT),
    ssh_username=SSH_USER,
    ssh_pkey=SSH_KEY,
    remote_bind_address=(SRC_REDIS_HOST, SRC_REDIS_PORT)
) as tunnel:

    src_redis = redis.Redis(
        host='127.0.0.1',
        port=tunnel.local_bind_port,
        db=SRC_REDIS_DB,
        password=SRC_REDIS_PASSWORD
    )

    # Connect to target Redis
    target_redis = redis.Redis(
        host=TARGET_REDIS_HOST,
        port=TARGET_REDIS_PORT,
        db=TARGET_REDIS_DB,
        password=TARGET_REDIS_PASSWORD
    )

    # Function to copy data from source to target Redis
    def sync_redis(src, target):
        for key in src.keys():
            key_type = src.type(key)
            if key_type == b'string':
                value = src.get(key)
                target.set(key, value)
            elif key_type == b'hash':
                all_hash_data = src.hgetall(key)
                for k, v in all_hash_data.items():
                    target.hset(key, k, v)
            elif key_type == b'list':
                all_list_data = src.lrange(key, 0, -1)
                for item in all_list_data:
                    target.rpush(key, item)
            elif key_type == b'set':
                all_set_data = src.smembers(key)
                for item in all_set_data:
                    target.sadd(key, item)
            elif key_type == b'zset':
                all_zset_data = src.zrange(key, 0, -1, withscores=True)
                for item, score in all_zset_data:
                    target.zadd(key, {item: score})
            else:
                print(f"Unsupported key type {key_type} for key {key}")

    # Sync data from source to target
    sync_redis(src_redis, target_redis)
    print("Data sync complete.")