import os
import json
import logging
import pams.db.fedschema as fedschema
from pika import ConnectionParameters
from pams.action import binstore, router, loopback
from pams.utils.connector import Connector
from pams.message_handler import MessageHandler

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s.%(msecs)03d %(levelname)-6s %(name)s(%(lineno)d) :: %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S')
logger = logging.getLogger(__name__)


def getenv(var: str):
    value = os.getenv(var)
    if not value:
        raise ValueError(f"Missing {var}")
    return value


def main() -> int:
    logger.setLevel(logging.DEBUG)
    logger.info("Starting")

    broker_host = getenv("BROKER_HOST")
    broker_port = int(getenv("BROKER_PORT"))
    broker_vhost = getenv("BROKER_VHOST")
    broker_admin_url = getenv("BROKER_ADMIN_URL")
    broker_admin_user = getenv("BROKER_ADMIN_USER")
    broker_admin_pwd = getenv("BROKER_ADMIN_PWD")
    topic = getenv("BROKER_REQUEST_QUEUE")
    max_users = int(getenv("MAX_USERS"))+2 #guest + admin
    db_type = getenv("DB_BACKEND")
    db_schema = getenv("PGSCHEMA")
    cos_access_key = getenv("S3_ACCESS_KEY")
    cos_secret_key = getenv("S3_SECRET_KEY")
    cos_endpoint = getenv("S3_ENDPOINT")

    logger.info("Creating RabbitMQ connection")
    connector = Connector(broker_host, broker_port, broker_vhost, broker_admin_user, broker_admin_pwd)

    logger.info("Creating DB connection")
    db = fedschema.FedSchema(db_schema) if db_type == "postgres" else None
    #TODO - Add DB2

    logger.info("Creating BinServer request handler")
    bin_server = binstore.BinServer(cos_access_key, cos_secret_key, cos_endpoint)

    db_config = {k.lower(): v for k, v in os.environ.items()}
    logger.info(db_config)

    logger.info("Creating Router request handler")
    access_manager = router.FFLAdmin(bin_server, db, connector, max_users, broker_admin_url,
                                        broker_admin_user, broker_admin_pwd, topic)

    logger.info("Creating Lo request handler")
    lo = loopback.Loopback()

    logger.info("Creating MessageHandler")
    message_handler = MessageHandler(access_manager, bin_server, lo)

    logger.info("Initiating message processing")
    connector.process_messages(topic, message_handler)

    logger.debug("Exit")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

