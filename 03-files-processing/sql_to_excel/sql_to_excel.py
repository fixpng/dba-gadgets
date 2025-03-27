# -*- coding: utf-8 -*-
"""
Created on Thu Sep 10 09:27:26 2020
@author: FixPng
批量执行sql输出excel (mysql、oracle)
因为业务系统运维需要执行的sql语句较多,也为了方便同事使用写了个执行sql的小工具,打包成exe后只需添加修改同目录下的excel文档即可管理
输出的结果每个sql对应excel一个页签
"""
import pandas as pd
import cx_Oracle
import pymysql
import datetime
import os
from time import strftime


def oracle_mode(df_sql,df_conf,out_path):
    try:
        connection = cx_Oracle.connect(df_conf.iloc[[0],[0]].values[0][0],
                                       df_conf.iloc[[0],[1]].values[0][0],
                                       df_conf.iloc[[0],[2]].values[0][0])
    except Exception as e:
        print('连接数据库出错!! ',e)
        return "ok"
    
    print(connection)
    today = datetime.date.today() # 1. 获取「今天」
    df = pd.read_excel('sql.xlsx')
    cursor = connection.cursor() #建立游标 
    try:
        #with pd.ExcelWriter(out_path) as writer:
        with pd.ExcelWriter(out_path,mode='a',engine='openpyxl') as writer:
            for i in range(len(df_sql)):
                sql = df_sql['sql'][i]                    
                cursor.execute(sql) #执行sql
                title = [j[0] for j in cursor.description] #获取oracle表头
                new_df = pd.DataFrame(cursor.fetchall())
                try:
                    new_df.to_excel(writer,sheet_name = df_sql['需求描述（简短）'][i],header=title, index=0)
                except:
                    print(df_sql['需求描述（简短）'][i],'执行结果为空')
                    continue
                
                print('已完成',df_sql['需求描述（简短）'][i],'的输出。')
    except Exception as e:
        print('执行输出过程出错!! ',e)
    finally:
        cursor.close()
        connection.close()
    return "ok"


def mysql_mode(df_sql,df_conf,out_path):
    try:
        connection = pymysql.connect(host=df_conf.iloc[[0],[2]].values[0][0].split("/")[0].split(":")[0],
                                    port=int(df_conf.iloc[[0],[2]].values[0][0].split("/")[0].split(":")[1]),
                                    user=df_conf.iloc[[0],[0]].values[0][0],
                                    password=df_conf.iloc[[0],[1]].values[0][0],
                                    database=df_conf.iloc[[0],[2]].values[0][0].split("/")[1],
                                    charset='utf8')

    except Exception as e:
        print('连接数据库出错!! ',e)
        return "ok"
    
    print(connection)
    today = datetime.date.today() # 1. 获取「今天」
    df = pd.read_excel('sql.xlsx')
    cursor = connection.cursor(cursor=pymysql.cursors.DictCursor) #建立游标 
    try:
        #with pd.ExcelWriter(out_path) as writer:
        with pd.ExcelWriter(out_path,mode='a',engine='openpyxl') as writer:
            for i in range(len(df_sql)):
                sql = df_sql['sql'][i]                    
                cursor.execute(sql) #执行sql
                title = [j[0] for j in cursor.description] #获取表头
                new_df = pd.DataFrame(cursor.fetchall())
                try:
                    new_df.to_excel(writer,sheet_name = df_sql['需求描述（简短）'][i],header=title, index=0)
                except:
                    print(df_sql['需求描述（简短）'][i],'执行结果为空')
                    continue
                
                print('已完成',df_sql['需求描述（简短）'][i],'的输出。')
    except Exception as e:
        print('执行输出过程出错!! ',e)
    finally:
        cursor.close()
        connection.close()
 

#主函数
if __name__ == "__main__":
    #刷新输出文件
    out_path = '.\output.xlsx'
    dataset = pd.DataFrame([[strftime("%Y-%m-%d %H:%M:%S"), "BBB"]], columns=["文件生成时间", "测试B列"])
    #print(dataset)
    with pd.ExcelWriter(out_path) as writer:
        dataset.to_excel(writer,sheet_name = '测试页', header=1,index=0)

    print('输出excel小程序开始执行。。。')
    df_xlsxs = input("请输入读取文件名(如sql.xlsx, 可用逗号分隔, 如 sql,stcmm,mpay )：")

    print('共'+str(df_xlsxs.count(",")+1)+'个文件需要执行')
    for i in range(df_xlsxs.count(",")+1):
        df_xlsx=df_xlsxs.split(",")[i]+'.xlsx'

        print('\n当前执行第'+str(i+1)+'个文件：'+df_xlsx)
        try:
            df_sql = pd.read_excel('.\\'+df_xlsx,sheet_name=0)  #执行的sql语句
            df_conf = pd.read_excel('.\\'+df_xlsx,sheet_name=1) #数据库连接配置
            type = pd.read_excel('.\\'+df_xlsx, None).keys()


            if 'mysql' in type:
                mysql_mode(df_sql,df_conf,out_path)
            elif 'oracle' in type:
                oracle_mode(df_sql,df_conf,out_path)
            else:
                print('暂无对应解析器（当前：oracle、mysql）\n')
        except Exception as e:
            print('执行文件有误!! 跳过本次 ',e)
            continue

    out = input('\n执行完毕！！结果已输出至'+out_path+' 回车退出。。。')