import get_etl_add_lineage

""" 
脚本功能：执行调用 open_metadata 血缘，当前录入血缘信息就用这个
192.168.31.130：crontab -e
05 19 * * * /usr/local/bin/python3 /data/scripts/data_lineage/execute_demo.py > /data/scripts/data_lineage/data_lineage.log &
"""
if __name__ == "__main__":
    # 数据血缘提取
    get_etl_add_lineage.GetCanalData().get_data_add_lineage()
    get_etl_add_lineage.GetDolphinSchedulerData().get_data_add_lineage()
    get_etl_add_lineage.GetStreamParkData().get_data_add_lineage()
    
    # get_etl_add_lineage.AllDemo.demo1()
    # get_etl_add_lineage.AllDemo.demo2()
    # get_etl_add_lineage.AllDemo.demo3()
    # get_etl_add_lineage.AllDemo.demo4()
    # get_etl_add_lineage.AllDemo.demo5()
    
    # data_sources = get_etl_add_lineage.GetDolphinSchedulerData().get_data_sources()
    # for source_id, url in data_sources.items():
    #     print(f"数据源ID: {source_id}, URL: {url}")