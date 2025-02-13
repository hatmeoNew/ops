import redis

SRC_REDIS_HOST = '127.0.0.1'
SRC_REDIS_PORT = 6379
SRC_REDIS_DB = 0
TAR_REDIS_DB = 12
SRC_REDIS_PASSWORD = ''

KEY = 'faq'

def copy_faq():
    src_conn = redis.Redis(host=SRC_REDIS_HOST, port=SRC_REDIS_PORT, db=SRC_REDIS_DB, password=SRC_REDIS_PASSWORD)
    tar_conn = redis.Redis(host=SRC_REDIS_HOST, port=SRC_REDIS_PORT, db=TAR_REDIS_DB, password=SRC_REDIS_PASSWORD)

    key_type = src_conn.type(KEY)
    if key_type == b'string':
        value = src_conn.get(KEY)
        tar_conn.set(KEY, value)
    elif key_type == b'hash':
        data = src_conn.hgetall(KEY)
        tar_conn.hmset(KEY, data)
    # Handle other Redis data types (list, set, etc.) as needed

copy_faq()
# ...existing code...