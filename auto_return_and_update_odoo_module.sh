PLUGIN_DIR=/www/wwwroot/custom_addons/

MODULE=${1:-sale_order_batch}

echo "要更新的模块: $MODULE"

cd "$PLUGIN_DIR" || exit 1

for dir in */; do
    if [ -d "$dir/.git" ]; then
        echo "Updating $dir"
        cd "$dir" || continue
        git pull
        cd ..
    fi
done

ODOO_DIR=/www/wwwroot/odoo_16/
cd "$ODOO_DIR" || exit 1

# restart odoo with restart.sh
if [ -f "restart.sh" ]; then

    echo "backup the odoo database"
    base backup_odoo_pg.sh

    echo "Restarting Odoo"

    # check if the module is in the list of modules to be updated
    if [ -z "$MODULE" ]; then
        echo "No module specified, restarting Odoo without updating any module"
    else
        echo "Updating module: $MODULE"
        # conda activate odoo
        conda activate odoo
        # update the module in the odoo database
        ./odoo-bin -d odoo_16_v2 -u "$MODULE" --stop-after-init --no-http --logfile=/tmp/odoo.log
    fi

    # restart odoo with supervisorctl
    supervisorctl restart odoo16

    #bash restart.sh "$MODULE"

    # get the git commit id of the module and get the commit user name
    cd "$PLUGIN_DIR$MODULE" || exit 1
    GIT_COMMIT_ID=$(git rev-parse HEAD)
    GIT_USER_NAME=$(git log -1 --pretty=format:'%an')

    # add the git commit id and user name to the message
    message="Odoo has been restarted successfully. Please check the logs for any issues. Module: $MODULE, Git Commit ID: $GIT_COMMIT_ID, User: $GIT_USER_NAME"

    # send msg to feishu + module name
    # message="Odoo has been restarted successfully. Please check the logs for any issues. Module: $MODULE"
    echo "Sending message to Feishu: $message"
    # send message to feishu
    curl -X POST -H "Content-Type: application/json" -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"$message\"}}" https://open.feishu.cn/open-apis/bot/v2/hook/054d1cae-c463-4200-ad83-4bea82bd07d6

else
    echo "restart.sh not found, skipping Odoo restart"
fi