#!/usr/bin/bash
# SSH 免密码登录脚本
# 您必须将脚本前两行的 SERVERS 列表和 PASSWORD 替换成您自己的实际机器列表和密码。
# 该脚本会自动生成 SSH 密钥对，并将公钥复制到所有指定的远程服务器上，从而实现免密码登录。
   
SERVERS=("<user>@<server_ip1>" "<user>@<server_ip2>" "<user>@<server_ip3>")
PASSWORD="******"
keygen() {
sudo yum -y install expect
expect -c "
   spawn ssh-keygen -t rsa
   expect {
      *(~/.ssh/id_rsa):* { send -- \r;exp_continue}
      *(y/n)* { send -- y\r;exp_continue}
      *Enter* { send -- \r;exp_continue}
      *(y/n)* { send -- y\r;exp_continue}
      *Enter* { send -- \r;exp_continue}
      eof {exit 0}
   }
   expect eof
"
}
copy(){
expect -c "
   set timeout -1
   spawn ssh-copy-id $1
   expect {
      *(yes/no)* { send -- yes\r; exp_continue }
      *password:* { send -- $PASSWORD\r; exp_continue}
      eof {exit 0}
   }
   expect eof
"
}
ssh_copy_id_to_all(){
keygen ;
for host in ${SERVERS[@]}
do
      copy $host
done
}
ssh_copy_id_to_all
