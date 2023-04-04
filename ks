





# 技能题

实验环境：
1 openvpn server： CentOS 8 eth0:10.10.0.81/24 桥接模式,模拟公网IP eth1:10.0.1.1/24 仅主机模式,私网IP
2 内网主机两台 第一台主机 eth0:10.0.1.100/24 仅主机模式,私网IP，无需网关 第二台主机 eth0:10.0.1.200/24 仅主机模式,私网IP，无需网关
3 Windows 客户端 Windows 10

关闭系统安全模式：
[root@centos8 ~]# vim /etc/sysconfig/selinux
SELINUX=disable
[root@centos8 ~]# setenforce 0
[root@centos8 ~]# echo 1 > /proc/sys/net/ipv4/ip_forward     #临时开启路由转发
[root@centos8 ~]# vi  /etc/sysctl.conf   #编辑配置文件，添加以下配置，设置永久路由转发
net.ipv4.ip_forward = 1

安装 OpenVPN
#OpenVPN服务器端
[root@centos8 ~]#yum -y install openvpn 
#证书管理工具
[root@centos8 ~]#yum -y install easy-rsa

准备相关配置文件
#生成服务器配置文件
[root@centos8 ~]#cp /usr/share/doc/openvpn/sample/sample-config-files/server.conf /etc/openvpn/
#准备证书签发相关文件
[root@centos8 ~]#cp -r /usr/share/easy-rsa/ /etc/openvpn/easy-rsa-server 
#准备签发证书相关变量的配置文件
[root@centos8 ~]#cp /usr/share/doc/easy-rsa/vars.example  /etc/openvpn/easy-rsa-server/3/vars
#建议修改给CA和OpenVPN服务器颁发的证书的有效期,可适当加长 
[root@centos8 ~]#vim /etc/openvpn/easy-rsa-server/3/vars 
#CA的证书有效期默为为10年,可以适当延长,比如:36500天
#set_var EASYRSA_CA_EXPIRE      3650 
set_var EASYRSA_CA_EXPIRE      36500
#服务器证书默为为825天,可适当加长,比如:3650天 
#set_var EASYRSA_CERT_EXPIRE    825 
#将上面行修改为下面
set_var EASYRSA_CERT_EXPIRE    3650 
[root@centos8 ~]#tree /etc/openvpn/
/etc/openvpn/
├── client
├── easy-rsa-server
│   ├── 3 -> 3.0.7
│   ├── 3.0 -> 3.0.7
│   └── 3.0.7
│       ├── easyrsa
│       ├── openssl-easyrsa.cnf
│       ├── vars
│       └── x509-types
│           ├── ca
│           ├── client
│           ├── code-signing
│           ├── COMMON
│           ├── email
│           ├── kdc
│           ├── server
│           └── serverClient 
├── server
└── server.conf
7 directories, 12 files

初始化PKI生成PKI相关目录和文件
[root@centos8 ~]#cd /etc/openvpn/easy-rsa-server/3/ 
[root@centos8 3]#ls
easyrsa  openssl-easyrsa.cnf  vars  x509-types
#初始化数据,在当前目录下生成pki目录及相关文件 
[root@centos8 3]#./easyrsa  init-pki
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-server/3.0.7/vars 
init-pki complete; you may now create a CA or requests.
Your newly created PKI dir is: /etc/openvpn/easy-rsa-server/3/pki 
[root@centos8 3]#tree
.
├── easyrsa
├── openssl-easyrsa.cnf
├── pki          #生成一个新目录及相关文件 
│   ├── openssl-easyrsa.cnf
│   ├── private 
│   ├── reqs
│   └── safessl-easyrsa.cnf 
├── vars
└── x509-types
    ├── ca
    ├── client
    ├── code-signing
    ├── COMMON
    ├── email
    ├── kdc
    ├── server
    └── serverClient
4 directories, 13 files

创建CA机构
[root@centos8 ~]#cd /etc/openvpn/easy-rsa-server/3 
[root@centos8 3]#tree pki
pki
├── openssl-easyrsa.cnf 
├── private
├── reqs
└── safessl-easyrsa.cnf 
2 directories, 2 files
[root@centos8 3]#./easyrsa build-ca nopass
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-server/3.0.7/vars
Using SSL: openssl OpenSSL 1.1.1c FIPS  28 May 2019 
Generating RSA private key, 2048 bit long modulus (2 primes)
...................................................+++++
........+++++
e is 65537 (0x010001)
You are about to be asked to enter information that will be incorporated 
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN. 
There are quite a few fields but you can leave some blank
For some fields there will be a default value, 
If you enter '.', the field will be left blank. 
-----
Common Name (eg: your user, host, or server name) [Easy-RSA CA]: #接受默认值,直接回车
CA creation complete and you may now import and sign cert requests. 
Your new CA certificate file for publishing is at: 
/etc/openvpn/easy-rsa-server/3/pki/ca.crt  #生成自签名的证书文件
[root@centos8 3]#tree pki 
pki
├── ca.crt                  #生成自签名的证书文件
├── certs_by_serial
├── index.txt
├── index.txt.attr 
├── issued
├── openssl-easyrsa.cnf
├── private
│   └── ca.key              #生成私钥文件 
├── renewed
│   ├── certs_by_serial 
│   ├── private_by_serial 
│   └── reqs_by_serial 
├── reqs
├── revoked
│   ├── certs_by_serial 
│   ├── private_by_serial 
│   └── reqs_by_serial 
├── safessl-easyrsa.cnf 
└── serial
12 directories, 7 files

创建服务端证书申请
[root@centos8 ~]#cd /etc/openvpn/easy-rsa-server/3 
[root@centos8 3]#pwd
/etc/openvpn/easy-rsa-server/3
#创建服务器证书申请文件，其中server是文件前缀
[root@centos8 3]#./easyrsa gen-req server nopass
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-server/3.0.7/vars 
Using SSL: openssl OpenSSL 1.1.1c FIPS  28 May 2019
Generating a RSA private key
..................+++++
................................................................................
....................................................+++++
writing new private key to '/etc/openvpn/easy-rsa-server/3/pki/easy-rsa- 
2135.JNDCBg/tmp.6nXb8b'
-----
You are about to be asked to enter information that will be incorporated 
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN. 
There are quite a few fields but you can leave some blank
For some fields there will be a default value, 
If you enter '.', the field will be left blank. 
-----
Common Name (eg: your user, host, or server name) [server]: #接受Common Name的默认值,直接回车
Keypair and certificate request completed. Your files are:
req: /etc/openvpn/easy-rsa-server/3/pki/reqs/server.req          #生成请求文件 
key: /etc/openvpn/easy-rsa-server/3/pki/private/server.key       #生成私钥文件
[root@centos8 3]#tree pki 
pki
├── ca.crt
├── certs_by_serial 
├── index.txt
├── index.txt.attr 
├── issued
├── openssl-easyrsa.cnf 
├── private
│   ├── ca.key
│   └── server.key       #生成私钥文件 
├── renewed
│   ├── certs_by_serial 
│   ├── private_by_serial 
│   └── reqs_by_serial 
├── reqs
│   └── server.req      #生成请求文件 
├── revoked
│   ├── certs_by_serial 
│   ├── private_by_serial 
│   └── reqs_by_serial 
├── safessl-easyrsa.cnf 
└── serial
12 directories, 9 files

颁发服务端证书
#将上面server.req的申请,颁发server类型的证书
[root@centos8 ~]#cd /etc/openvpn/easy-rsa-server/3 
  [root@centos8 3]#./easyrsa sign server server
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-server/3.0.7/vars
Using SSL: openssl OpenSSL 1.1.1c FIPS  28 May 2019
You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request 
has not been cryptographically verified. Please be sure it came from a trusted 
source or that you have verified the request checksum with the sender.
Request subject, to be signed as a server certificate for 3650 days:   #可以看到vars文件指定的有效期
subject=
    commonName                = server
Type the word 'yes' to continue, or any other input to abort. 
  Confirm request details: yes #输入yes回车
Using configuration from /etc/openvpn/easy-rsa-server/3/pki/easy-rsa- 
2334.MEAQFE/tmp.SIdgaC
Check that the request matches the signature 
Signature ok
The Subject's Distinguished Name is as follows 
commonName            :ASN.1 12:'server'
Certificate is to be certified until Oct 31 09:19:43 2020 GMT (90 days) 
Write out database with 1 new entries
Data Base Updated
Certificate created at: /etc/openvpn/easy-rsa-server/3/pki/issued/server.crt #生成服务器证书文件

创建 Diffie-Hellman 密钥
[root@centos8 ~]#cd /etc/openvpn/easy-rsa-server/3 
[root@centos8 3]#pwd
/etc/openvpn/easy-rsa-server/3
#方法1
[root@centos8 3]#./easyrsa gen-dh
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-server/3.0.7/vars 
Using SSL: openssl OpenSSL 1.1.1c FIPS  28 May 2019
Generating DH parameters, 2048 bit long safe prime, generator 2 
This is going to take a long time
................+..................................+............................
..........................++*++*++*++*
.......#需要等待一会儿
DH parameters of size 2048 created at /etc/openvpn/easy-rsa-sever/3/pki/dh.pem 

#方法2
[root@centos8 ~]#openssl dhparam -out /etc/openvpn/dh2048.pem 2048 
[root@centos8 ~]#ll /etc/openvpn/dh2048.pem
-rw-r--r-- 1 root root 424 Aug  3 20:50 /etc/openvpn/dh2048.pem
服务端证书配置完成

准备客户端证书环境
[root@centos8 ~]#cp -r /usr/share/easy-rsa/ /etc/openvpn/easy-rsa-client 
#可选
[root@centos8 ~]#cp /usr/share/doc/easy-rsa/vars.example /etc/openvpn/easy-rsa-client/3/vars
[root@centos8 ~]#cd /etc/openvpn/easy-rsa-client/3/ 
[root@centos8 3]#tree
.
├── easyrsa
├── openssl-easyrsa.cnf 
├── vars
└── x509-types
    ├── ca
    ├── client
    ├── code-signing
    ├── COMMON
    ├── email
    ├── kdc
    ├── server
    └── serverClient
1 directory, 11 files
#生成证书申请所需目录pki和文件
[root@centos8 3]#./easyrsa init-pki
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-client/3.0.7/vars 
init-pki complete; you may now create a CA or requests.
Your newly created PKI dir is: /etc/openvpn/easy-rsa-client/3/pki  #生成新目录 
[root@centos8 3]#tree
.
├── easyrsa
├── openssl-easyrsa.cnf
├── pki                                 #生成新目录 
│   ├── openssl-easyrsa.cnf
│   ├── private 
│   ├── reqs
│   └── safessl-easyrsa.cnf 
├── vars
└── x509-types
    ├── ca
    ├── client
    ├── code-signing 
    ├── COMMON
    ├── email
    ├── kdc
    ├── server
    └── serverClient 
4 directories, 13 files

创建客户端证书申请
[root@centos8 ~]#cd /etc/openvpn/easy-rsa-client/3 
#生成客户端用户的证书申请
[root@centos8 3]#./easyrsa  gen-req USERNAME nopass
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-client/3.0.7/vars 
Using SSL: openssl OpenSSL 1.1.1c FIPS  28 May 2019
Generating a RSA private key
.......................................................+++++
................................................................................
.........................+++++
writing new private key to '/etc/openvpn/easy-rsa-client/3/pki/easy-rsa- 
3467.v5FPPS/tmp.GsttV6'
-----
You are about to be asked to enter information that will be incorporated 
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN. 
There are quite a few fields but you can leave some blank
For some fields there will be a default value, 
If you enter '.', the field will be left blank. 
-----
Common Name (eg: your user, host, or server name) [USERNAME]:  #接受默认值,直接回车
Keypair and certificate request completed. Your files are:
req: /etc/openvpn/easy-rsa-client/3/pki/reqs/USERNAME.req      #私钥文件 
key: /etc/openvpn/easy-rsa-client/3/pki/private/USERNAME.key    #证书申请文件
#生成两个新文件
[root@centos8 3]#tree
.
├── easyrsa
├── openssl-easyrsa.cnf 
├── pki
│   ├── openssl-easyrsa.cnf 
│   ├── private
│   │   └── USERNAME.key  #私钥文件 
│   ├── reqs
│   │   └── USERNAME.req  #证书申请文件 
│   └── safessl-easyrsa.cnf
├── vars
└── x509-types 
    ├── ca
    ├── client
    ├── code-signing 
    ├── COMMON
    ├── email
    ├── kdc
    ├── server
    └── serverClient 
4 directories, 15 files

签发客户端证书
[root@centos8 ~]#cd /etc/openvpn/easy-rsa-server/3 
#将客户端证书请求文件复制到CA的工作目录
[root@centos8 3]#./easyrsa import-req /etc/openvpn/easy-rsa-client/3/pki/reqs/USERNAME.req USERNAME
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-server/3.0.7/vars 
Using SSL: openssl OpenSSL 1.1.1c FIPS  28 May 2019
The request has been successfully imported with a short name of: USERNAME 
You may now use this name to perform signing operations on this request.
[root@centos8 3]#tree pki 
pki
├── ca.crt
├── certs_by_serial
│   └── EDAEBAB8D65066D307AE58ADC1A56682.pem 
├── dh.pem
├── index.txt
├── index.txt.attr
├── index.txt.attr.old 
├── index.txt.old
├── issued
│   └── server.crt
├── openssl-easyrsa.cnf 
├── private
│   ├── ca.key 
│   └── server.key 
├── renewed
│   ├── certs_by_serial 
│   ├── private_by_serial 
│   └── reqs_by_serial 
├── reqs
│   ├── server.req
│   └── USERNAME.req   #导入文件 
├── revoked
│   ├── certs_by_serial 
│   ├── private_by_serial 
│   └── reqs_by_serial 
├── safessl-easyrsa.cnf 
├── serial
└── serial.old
12 directories, 16 files

#修改给客户端颁发的证书的有效期
[root@centos8 3]#vim vars
#建议修改给客户端颁发证书的有效期,可适当减少,比如:90天 
#set_var EASYRSA_CERT_EXPIRE    825
#将上面行修改为下面
set_var EASYRSA_CERT_EXPIRE 90 
#签发客户端证书
[root@centos8 3]#./easyrsa sign client USERNAME
Note: using Easy-RSA configuration from: /etc/openvpn/easy-rsa-server/3.0.7/vars 
Using SSL: openssl OpenSSL 1.1.1c FIPS  28 May 2019
You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request 
has not been cryptographically verified. Please be sure it came from a trusted 
source or that you have verified the request checksum with the sender.
Request subject, to be signed as a client certificate for 90 days: 
subject=
    commonName                = USERNAME
Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: yes                      #输入yes后回车 
Using configuration from /etc/openvpn/easy-rsa-server/3/pki/easy-rsa- 
3617.XN7fIU/tmp.P7NKo8
Check that the request matches the signature 
Signature ok
The Subject's Distinguished Name is as follows 
commonName            :ASN.1 12:'USERNAME'
Certificate is to be certified until Oct 31 15:38:15 2020 GMT (90 days) 
Write out database with 1 new entries
Data Base Updated
Certificate created at: /etc/openvpn/easy-rsa- 
server/3/pki/issued/USERNAME.crt #证书文件
[root@centos8 3]#tree pki 
pki
├── ca.crt
├── certs_by_serial
│   ├── 5FE114ACC4FE6AB89D17E1B0EECF2B78.pem 
│   └── EDAEBAB8D65066D307AE58ADC1A56682.pem 
├── dh.pem
├── index.txt
├── index.txt.attr 
├── index.txt.attr.old
├── index.txt.old 
├── issued
│   ├── server.crt
│   └── USERNAME.crt          #生成客户端证书
├── openssl-easyrsa.cnf
├── private
│   ├── ca.key 
│   └── server.key 
├── renewed
│   ├── certs_by_serial 
│   ├── private_by_serial 
│   └── reqs_by_serial 
├── reqs
│   ├── server.req
│   └── USERNAME.req 
├── revoked
│   ├── certs_by_serial 
│   ├── private_by_serial 
│   └── reqs_by_serial 
├── safessl-easyrsa.cnf 
├── serial
└── serial.old
12 directories, 18 files

如果需要颁发的客户端证书较多,可以使用下面脚本实现客户端证书的批量颁发
客户端证书自动颁发脚本
[root@centos8 ~]#cat openvpn-user-crt.sh
#!/bin/bash
#
read -p "请输入用户的姓名拼音(如:${NAME}): " NAME
cd /etc/openvpn/easy-rsa-client/3
./easyrsa  gen-req ${NAME} nopass <<EOF 
EOF
cd /etc/openvpn/easy-rsa-server/3
./easyrsa import-req /etc/openvpn/easy-rsa-client/3/pki/reqs/${NAME}.req ${NAME} 
./easyrsa sign client ${NAME} <<EOF
yes
EOF

将CA和服务器证书相关文件复制到服务器相应的目录
[root@centos8 ~]#mkdir /etc/openvpn/certs
[root@centos8 ~]#cp /etc/openvpn/easy-rsa-server/3/pki/ca.crt /etc/openvpn/certs/
[root@centos8 ~]#cp /etc/openvpn/easy-rsa-server/3/pki/issued/server.crt /etc/openvpn/certs/
[root@centos8 ~]#cp /etc/openvpn/easy-rsa-server/3/pki/private/server.key /etc/openvpn/certs/        
[root@centos8 ~]#cp /etc/openvpn/easy-rsa-server/3/pki/dh.pem /etc/openvpn/certs/
[root@centos8 ~]#ll /etc/openvpn/certs/ 
total 20
-rw------- 1 root root 1204 Aug  3 20:34 ca.crt 
-rw------- 1 root root  424 Aug  3 20:35 dh.pem 
-rw------- 1 root root 4608 Aug  3 20:34 server.crt 
-rw------- 1 root root 1704 Aug  3 20:35 server.key

将客户端私钥与证书相关文件复制到服务器相关的目录
[root@centos8 ~]#mkdir /etc/openvpn/client/USERNAME/
[root@centos8 ~]#find /etc/openvpn/  -name "USERNAME.key" -o -name "USERNAME.crt" -o -name ca.crt
/etc/openvpn/easy-rsa-client/3.0.7/pki/private/USERNAME.key 
/etc/openvpn/easy-rsa-server/3.0.7/pki/issued/USERNAME.crt 
/etc/openvpn/easy-rsa-server/3.0.7/pki/ca.crt 
/etc/openvpn/certs/ca.crt
[root@centos8 ~]#find /etc/openvpn/ \( -name "USERNAME.key" -o -name "USERNAME.crt" -o -name ca.crt \) -exec cp {} /etc/openvpn/client/USERNAME \;
[root@centos8 ~]#ll /etc/openvpn/client/USERNAME/ 
total 16
-rw------- 1 root root 1204 Aug  3 21:05 ca.crt
-rw------- 1 root root 4506 Aug  3 21:05 USERNAME.crt 
-rw------- 1 root root 1704 Aug  3 21:05 USERNAME.key

准备 OpenVPN 服务器配置文件
修改服务器端配置文件
[root@centos8 ~]#vim /etc/openvpn/server.conf

服务器端配置文件说明
#server.conf文件中以#或;开头的行都为注释
[root@centos8 ~]#grep -Ev "^#|^$" /etc/openvpn/server.conf 
;local a.b.c.d  #本机监听IP,默认为本机所有IP
port 1194       #端口
;proto tcp      #协议,生产推荐使用TCP 
proto udp       #默认协议
;dev tap   #创建一个以太网隧道，以太网使用tap,一个tap设备允许完整的以太网帧通过Openvpn隧道，可提供非ip协议的支持，比如IPX协议和AppleTalk协议,tap等同于一个以太网设备，它操作第二层数据包如以太网数据帧。
dev tun    #创建一个路由IP隧道，生产推存使用tun.互联网使用tun,一个tun设备大多时候，被用于基于IP协议的通讯。tun模拟了网络层设备，操作第三层数据包比如IP数据封包。
;dev-node MyTap  #TAP-Win32适配器。非windows不需要配置 
ca  ca.crt       #ca证书文件
cert server.crt  #服务器证书文件 
key server.key   #服务器私钥文件 
dh dh2048.pem    #dh参数文件 
;topology subnet
server 10.8.0.0 255.255.255.0  #客户端连接后分配IP的地址池，服务器默认会占用第一个IP10.8.0.1将做为客户端的网关
ifconfig-pool-persist ipp.txt  #为客户端分配固定IP，不需要配置,建议注释
;server-bridge 10.8.0.4 255.255.255.0 10.8.0.50 10.8.0.100  #配置网桥模式，不需要配置,建议注释
;server-bridge
;push "route 192.168.10.0 255.255.255.0"  #给客户端生成的到达服务器后面网段的静态路由，下一跳为openvpn服务器的10.8.0.1
;push "route 192.168.20.0 255.255.255.0"  #推送路由信息到客户端，以允许客户端能够连接到服务器背后的其它私有子网
;client-config-dir ccd              #为指定的客户端添加路由，此路由通常是客户端后面的内网网段而不是服务端的，也不需要设置
;route 192.168.40.128 255.255.255.248 
;client-config-dir ccd    
;route 10.9.0.0 255.255.255.252
;learn-address ./script                #运行外部脚本，创建不同组的iptables规则，无需配置
;push "redirect-gateway def1 bypass-dhcp" #启用后，客户端所有流量都将通过VPN服务器，因此生产一般无需配置此项
;push "dhcp-option DNS 208.67.222.222"   #推送DNS服务器，不需要配置 
;push "dhcp-option DNS 208.67.220.220"
;client-to-client                       #允许不同的client直接通信,不安全,生产环境一般无需要配置
;duplicate-cn                           #多个用户共用一个证书，一般用于测试环境，生产环境都是一个用户一个证书,无需开启
keepalive 10 120         #设置服务端检测的间隔和超时时间，默认为每10秒ping一次，如果120秒没有回应则认为对方已经down
tls-auth ta.key 0       #访止DoS等攻击的安全增强配置,可以使用以下命令来生成：openvpn -- 
genkey --secret ta.key #服务器和每个客户端都需要拥有该密钥的一个拷贝。第二个参数在服务器端应该为’0’，在客户端应该为’1’
cipher AES-256-CBC  #加密算法
;compress lz4-v2    #启用Openvpn2.4.X新版压缩算法
;push "compress lz4-v2"   #推送客户端使用新版压缩算法,和下面的comp-lzo不要同时使用
;comp-lzo          #旧户端兼容的压缩配置，需要客户端配置开启压缩,openvpn2.4.X等新版可以不用开启
;max-clients 100   #最大客户端数
;user nobody         #运行openvpn服务的用户和组 
;group nobody
persist-key          #重启VPN服务时默认会重新读取key文件，开启此配置后保留使用第一次的key文件,生产环境无需开启
persist-tun          #启用此配置后,当重启vpn服务时，一直保持tun或者tap设备是up的，否则会先down然后再up,生产环境无需开启
status openvpn-status.log #openVPN状态记录文件，每分钟会记录一次
;log         openvpn.log   #第一种日志记录方式,并指定日志路径，log会在openvpn启动的时候清空日志文件,不建议使用
;log-append  openvpn.log   #第二种日志记录方式,并指定日志路径，重启openvpn后在之前的日志后面追加新的日志,生产环境建议使用
verb 3                   #设置日志级别，0-9，级别越高记录的内容越详细,0 表示静默运行，只记录致命错误,4 表示合理的常规用法,5 和 6 可以帮助调试连接错误。9 表示极度冗余，输出非常详细的日志信息
;mute 20                 #相同类别的信息只有前20条会输出到日志文件中
explicit-exit-notify 1   #通知客户端，在服务端重启后自动重新连接，仅能用于udp模式，tcp模式不需要配置即可实现断开重新连接,且开启此项后tcp配置后将导致openvpn服务无法启动,所以tcp时必须不能开启此项

修改服务器端配置文件
[root@centos8 ~]#vim /etc/openvpn/server.conf
[root@centos8 ~]#grep '^[a-Z].*' /etc/openvpn/server.conf 
port 1194
proto tcp
dev tun
ca /etc/openvpn/certs/ca.crt
cert /etc/openvpn/certs/server.crt
key /etc/openvpn/certs/server.key  # This file should be kept secret
dh /etc/openvpn/certs/dh.pem
server 10.8.0.0 255.255.255.0
push "route 10.10.0.0 255.255.255.0"
keepalive 10 120
cipher AES-256-CBC
compress lz4-v2
push "compress lz4-v2"
max-clients 2048
user openvpn
group openvpn
status /var/log/openvpn/openvpn-status.log
log-append   /var/log/openvpn/openvpn.log
verb 3
mute 20
#准备目志相关目录
[root@centos8 ~]#getent passwd openvpn
openvpn:x:993:990:OpenVPN:/etc/openvpn:/sbin/nologin 
[root@centos8 ~]#mkdir /var/log/openvpn
[root@centos8 ~]#chown openvpn.openvpn /var/log/openvpn 
[root@centos8 ~]#ll -d /var/log/openvpn
drwxr-xr-x 2 openvpn openvpn 6 Aug  3 23:07 /var/log/openvpn

准备 iptables 规则和内核参数
#在服务器开启ip_forward转发功能
[root@centos8 ~]#echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf 
[root@centos8 ~]#sysctl -p
net.ipv4.ip_forward = 1 
#添加SNAT规则
[root@centos8 ~]#echo 'iptables -t nat -A POSTROUTING -s 10.10.0.0/24  -j MASQUERADE' >> /etc/rc.d/rc.local
[root@centos8 ~]#chmod +x /etc/rc.d/rc.local 
[root@centos8 ~]#/etc/rc.d/rc.local
[root@centos8 ~]#iptables -vnL
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination 
Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination 
Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
[root@centos8 ~]#iptables -vnL -t nat
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination 
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination 
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination 
    0     0 MASQUERADE  all  --  *      *       10.10.0.0/24          0.0.0.0/0  
Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

启动 OpenVPN 服务
[root@centos7 ~]#rpm -ql openvpn|grep systemd 
/usr/lib/systemd/system/openvpn-client@.service 
/usr/lib/systemd/system/openvpn-server@.service 
/usr/lib/systemd/system/openvpn@.service 
/usr/share/doc/openvpn-2.4.9/README.systemd
#CentOS8 缺失unit文件,从CentOS7复制文件
[root@centos8 ~]#rpm -ql openvpn|grep systemd 
/usr/lib/systemd/system/openvpn-client@.service 
/usr/lib/systemd/system/openvpn-server@.service 
/usr/share/doc/openvpn/README.systemd
[root@centos7 ~]#cat /usr/lib/systemd/system/openvpn@.service 
[Unit]
Description=OpenVPN Robust And Highly Flexible Tunneling Application On %I 
After=network.target
[Service]
Type=notify 
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf 
[Install]
WantedBy=multi-user.target
[root@centos7 ~]#scp /lib/systemd/system/openvpn@.service 10.10.0.81:/lib/systemd/system/
#启动OpenVPN服务,注意service名称和文件名不一致 
[root@centos8 openvpn]#systemctl daemon-reload
[root@centos8 openvpn]#systemctl enable --now openvpn@server

查看服务状态
[root@centos8 openvpn]#systemctl status openvpn@server
● openvpn@server.service - OpenVPN Robust And Highly Flexible Tunneling Application On server
   Loaded: loaded (/usr/lib/systemd/system/openvpn@.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2022-05-19 16:25:43 CST; 3min 49s ago
 Main PID: 7696 (openvpn)
   Status: "Initialization Sequence Completed"
    Tasks: 1 (limit: 4724)
   Memory: 2.0M
   CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
           └─7696 /usr/sbin/openvpn --cd /etc/openvpn/ --config server.conf
Aug 04 00:30:12 centos8.localdomain systemd[1]: Starting OpenVPN Robust And Highly Flexible Tunneling Application >
Aug 04 00:30:12 centos8.localdomain systemd[1]: Started OpenVPN Robust And Highly Flexible Tunneling Application
#注意端口号
[root@centos8 ~]#ss -ntlp
State  Recv-Q  Send-Q   Local Address:Port   Peer Address:Port Process                                                   
LISTEN 0       32             0.0.0.0:1194        0.0.0.0:*     users:(("openvpn",pid=7696,fd=8))                        
LISTEN 0       128            0.0.0.0:111         0.0.0.0:*     users:(("rpcbind",pid=887,fd=4),("systemd",pid=1,fd=34)) 
LISTEN 0       128            0.0.0.0:22          0.0.0.0:*     users:(("sshd",pid=938,fd=4))                            
LISTEN 0       128               [::]:111            [::]:*     users:(("rpcbind",pid=887,fd=6),("systemd",pid=1,fd=36)) 
LISTEN 0       128               [::]:22             [::]:*     users:(("sshd",pid=938,fd=6))     
[root@centos8 ~]#ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group 
default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00 
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever 
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP 
group default qlen 1000
    link/ether 00:0c:29:8a:51:21 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.8/24 brd 10.0.0.255 scope global noprefixroute eth0 
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fe8a:5121/64 scope link 
       valid_lft forever preferred_lft forever
3: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state 
UNKNOWN group default qlen 100
    link/none
    inet 10.8.0.1 peer 10.8.0.2/32 scope global tun0 
       valid_lft forever preferred_lft forever
    inet6 fe80::c8db:a8ca:b492:a3e0/64 scope link stable-privacy 
       valid_lft forever preferred_lft forever
[root@centos8 ~]#route -n 
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.30.0.253    0.0.0.0         UG    100    0        0 eth0
10.8.0.0        10.8.0.2        255.255.255.0   UG    0      0        0 tun0
10.8.0.2        0.0.0.0         255.255.255.255 UH    0      0        0 tun0
172.30.0.0      0.0.0.0         255.255.255.0   U     100    0        0 eth0

准备 OpenVPN 客户端配置文件
客户端默认范例配置文件说明
[root@centos8 ~]#grep '^[[:alpha:]].*' /usr/share/doc/openvpn/sample/sample-config-files/client.conf
client     #声明自己是个客户端
dev tun    #接口类型，必须和服务端保持一致 
proto udp  #协议类型，必须和服务端保持一致
remote my-server-1 1194 #server端的ip和端口，可以写域名但是需要可以解析成IP
resolv-retry infinite   #如果是写的server端的域名，那么就始终解析，如果域名发生变化，会重新连接到新的域名对应的IP
nobind                  #本机不绑定监听端口，客户端是随机打开端口连接到服务端的1194 
persist-key
persist-tun 
ca ca.crt 
cert client.crt 
key client.key
remote-cert-tls server  #指定采用服务器证书校验方式 
tls-auth ta.key 1
cipher AES-256-CBC 
verb 3

生成客户端用户的配置文件
#生成客户端文件,文件后缀必须为.ovpn
[root@centos8 ~]#grep '^[[:alpha:]].*' /usr/share/doc/openvpn/sample/sample-config-files/client.conf > /etc/openvpn/client/USERNAME/client.ovpn
#修改配置文件,内容如下
[root@centos8 ~]#vim /etc/openvpn/client/USERNAME/client.ovpn 
[root@centos8 ~]#cat /etc/openvpn/client/USERNAME/client.ovpn 
client
dev tun 
proto tcp
remote  10.10.0.81  1194              #生产中为OpenVPN公网IP 
resolv-retry infinite
nobind
#persist-key 
#persist-tun
ca ca.crt
cert USERNAME.crt 
key USERNAME.key 
remote-cert-tls server
#tls-auth ta.key 1
cipher AES-256-CBC
verb 3                              #此值不能随意指定,否则无法通信
compress lz4-v2                     #此项在OpenVPN2.4.X版本使用,需要和服务器端保持一致,如不指定,默认使用comp-lz压缩

完整安装脚本
#!/bin/bash

#================================================================
#   
#   文件名称：openvpn-install.sh
#   创 建 者：Tdison
#   创建日期：2022年05月22日
#   描    述：
#
#================================================================

echo "正在运行openvpn安装脚本。"
echo
sudo sed -i.bak 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0 > /dev/null
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf

yum install openvpn -y 
yum install easy-rsa -y 

#修改服务端配置
cp /usr/share/doc/openvpn/sample/sample-config-files/server.conf /etc/openvpn/
cp -r /usr/share/easy-rsa/ /etc/openvpn/easy-rsa-server 
cp /usr/share/doc/easy-rsa/vars.example /etc/openvpn/easy-rsa-server/3/vars
sed -ri 's/#set_var EASYRSA_CA_EXPIRE[[:space:]]+3650/set_var EASYRSA_CA_EXPIRE       36500/' /etc/openvpn/easy-rsa-server/3/vars
sed -ri 's/#set_var EASYRSA_CERT_EXPIRE[[:space:]]+825/set_var EASYRSA_CERT_EXPIRE       3650/' /etc/openvpn/easy-rsa-server/3/vars 
cd /etc/openvpn/easy-rsa-server/3/ && ./easyrsa init-pki && ./easyrsa build-ca nopass && ./easyrsa gen-req server nopass && ./easyrsa sign server server && ./easyrsa gen-dh && ./easyrsa gen-crl

#修改客户端配置
echo
read -p "请输入用户名: " USERNAME
cp -r /usr/share/easy-rsa/ /etc/openvpn/easy-rsa-client 
cp /usr/share/doc/easy-rsa/vars.example /etc/openvpn/easy-rsa-client/3/vars
cd /etc/openvpn/easy-rsa-client/3/ && ./easyrsa init-pki && ./easyrsa  gen-req $USERNAME nopass 
cd /etc/openvpn/easy-rsa-server/3/ && ./easyrsa import-req /etc/openvpn/easy-rsa-client/3/pki/reqs/$USERNAME.req $USERNAME
sed -ri 's/set_var EASYRSA_CERT_EXPIRE[[:space:]]+3650/set_var EASYRSA_CERT_EXPIRE       90/' /etc/openvpn/easy-rsa-server/3/vars 
cd /etc/openvpn/easy-rsa-server/3/ && ./easyrsa sign client $USERNAME 

mkdir /etc/openvpn/certs
cp /etc/openvpn/easy-rsa-server/3/pki/ca.crt /etc/openvpn/certs/
cp /etc/openvpn/easy-rsa-server/3/pki/issued/server.crt /etc/openvpn/certs/
cp /etc/openvpn/easy-rsa-server/3/pki/private/server.key /etc/openvpn/certs/
cp /etc/openvpn/easy-rsa-server/3/pki/dh.pem /etc/openvpn/certs/

mkdir /etc/openvpn/client/$USERNAME/
find /etc/openvpn/ \( -name "$USERNAME.key" -o -name "$USERNAME.crt" -o -name ca.crt \) -exec cp {} /etc/openvpn/client/$USERNAME \;

# 如果系统只有一个IPv4，它将自动被选中。否则，请让用户选择。
if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
  ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
else
  number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
  echo
  echo "使用哪个公网IPv4地址？"
  ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
  read -p "IPv4 address [1]: " ip_number
  until [[ -z "$ip_number" || "$ip_number" =~ ^[0-9]+$ && "$ip_number" -le "$number_of_ip" ]]; do
    echo "$ip_number: invalid selection."
    read -p "IPv4 address [1]: " ip_number
  done
  [[ -z "$ip_number" ]] && ip_number="1"
  ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_number"p)
fi

# 如果系统只有一个网关，它将自动被选中。否则，请让用户选择。
if [[ $(route | cut -d ' ' -f 1 | grep -Ec '([0-9]{1,3}.){3}[0-9]{1,3}') -eq 1 ]]; then
  Genmask=$(route | awk -F"[[:space:]]+" '{print $3}' | grep -E '([0-9]{1,3}.){3}[0^C]{1,3}' | grep -vE '0.0.0.0')
  Gateway=$(route | cut -d ' ' -f 1 | grep -E '([0-9]{1,3}.){3}[0-9]{1,3}')
else
  number_of_Gateway=$(route | cut -d ' ' -f 1 | grep -Ec '([0-9]{1,3}.){3}[0-9]{1,3}')
  echo
  echo "使用哪个私网网关地址？"
  route | cut -d ' ' -f 1 | grep -E '([0-9]{1,3}.){3}[0-9]{1,3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
  read -p "Gateway [1]: " Gateway_number
  until [[ -z "$Gateway_number" || "$Gateway_number" =~ ^[0-9]+$ && "$Gateway_number" -le "$number_of_Gateway" ]]; do
    echo "$Gateway_number: invalid selection."
    read -p "Gateway [1]: " Gateway_number
  done
  [[ -z "$Gateway_number" ]] && Gateway_number="1"

  Genmask=$(route | awk -F"[[:space:]]+" '{print $3}' | grep -E '([0-9]{1,3}.){3}[0^C]{1,3}' | grep -vE '0.0.0.0' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$Gateway_number"p)
  Gateway=$(route | cut -d ' ' -f 1 | grep -E '([0-9]{1,3}.){3}[0-9]{1,3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$Gateway_number"p)
fi

#选择协议
echo
echo "OpenVPN应该使用哪种协议？"
echo "   1) UDP (推荐)"
echo "   2) TCP"
read -p "Protocol [1]: " protocol
until [[ -z "$protocol" || "$protocol" =~ ^[12]$ ]]; do
  echo "$protocol: 选择无效。"
  read -p "Protocol [1]: " protocol
done
case "$protocol" in
  1|"") 
  protocol=udp
  ;;
  2) 
  protocol=tcp
  ;;
esac

#选择端口
echo
echo "OpenVPN应该监听哪个端口？"
  read -p "Port [1194]: " port
  until [[ -z "$port" || "$port" =~ ^[0-9]+$ && "$port" -le 65535 ]]; do
    echo "$port: 端口无效。"
    read -p "Port [1194]: " port
  done
  [[ -z "$port" ]] && port="1194"

echo
echo "服务器配置文件"
tee /etc/openvpn/server.conf << EOF
port $port
proto $protocol
dev tun
ca /etc/openvpn/certs/ca.crt
cert /etc/openvpn/certs/server.crt
key /etc/openvpn/certs/server.key  # This file should be kept secret
dh /etc/openvpn/certs/dh.pem
server 10.8.0.0 255.255.255.0
push "route $Gateway $Genmask"
keepalive 10 120
cipher AES-256-CBC
compress lz4-v2
push "compress lz4-v2"
max-clients 2048
user openvpn
group openvpn
status /var/log/openvpn/openvpn-status.log
log-append   /var/log/openvpn/openvpn.log
verb 3
mute 20
EOF
echo

yum install iptables-services iptables -y
systemctl enable iptables --now 
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z
iptables -t nat -A POSTROUTING -s 10.8.0.0/16 -j MASQUERADE
iptables -A INPUT -p TCP --dport 1194 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
service iptables save >> /dev/null

mkdir /var/log/openvpn
chown openvpn.openvpn /var/log/openvpn

echo
echo "客户端配置文件"
tee /etc/openvpn/client/$USERNAME/client.ovpn <<EOF
client
dev tun 
proto $protocol
remote  $ip  $port
resolv-retry infinite
nobind
ca ca.crt
cert $USERNAME.crt 
key $USERNAME.key 
remote-cert-tls server
cipher AES-256-CBC
verb 3
compress lz4-v2
EOF
echo

echo '[Unit]
Description=OpenVPN Robust And Highly Flexible Tunneling Application On %I 
After=network.target
[Service]
Type=notify 
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf 
[Install]
WantedBy=multi-user.target' > /usr/lib/systemd/system/openvpn@.service 
systemctl daemon-reload
systemctl enable --now openvpn@server 

cd /etc/openvpn/client/$USERNAME/
tar cf ~/$USERNAME.tar  ./ 
echo
echo "客户端配置在: ~/$USERNAME.tar"

Windows 配置部署 OpenVPN 客户端
下载并安装OpenVPN 客户端：https://openvpn.net/community-downloads/

Windows 客户端配置准备
#在服务器打包证书并下载发送给windows客户端
[root@centos8 ~]#cd /etc/openvpn/client/USERNAME/ 
[root@centos8 USERNAME]#tar cf USERNAME.tar  ./ 
tar: ./USERNAME.tar: file is the archive; not dumped 
[root@centos8 USERNAME]#ll
total 40
-rw------- 1 root root  1204 Aug  3 21:05 ca.crt
-rw-r--r-- 1 root root   231 Aug  3 23:31 client.ovpn
-rw------- 1 root root  4506 Aug  3 21:05 USERNAME.crt 
-rw------- 1 root root  1704 Aug  3 21:05 USERNAME.key 
-rw-r--r-- 1 root root 20480 Aug  4 10:48 USERNAME.tar
[root@centos8 USERNAME]#tar tf USERNAME.tar 
./
./USERNAME.key 
./USERNAME.crt 
./ca.crt
./client.ovpn
解压到windows客户端的C:\Program Files\OpenVPN\config目录下。
Windows 客户端建立OpenVPN连接
在windows 程序中打开OpenVPN GUI工具,右键状态栏图标,点连接。

参考：https://mp.weixin.qq.com/s/bwxQr3YuOBOHrx4am4xn8Q
