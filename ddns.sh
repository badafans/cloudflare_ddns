#!/bin/bash
# CF DDNS

#这里填写区域ID
zone_id=当前域名的区域ID
#API Bearer密钥,在 https://dash.cloudflare.com/profile/api-tokens 创建编辑区域 DNS
bearer=你的Bearer密钥
#需要修改DNS的域名
domain=完整域名
#DDNS IP类型ipv4,ipv6,默认是ipv4
ips=ipv4

function cloudflaredns(){
id=$(curl -s "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" -H "Authorization: Bearer $bearer" | sed -e 's/{/\n/g' -e 's/"proxiable"/\n/g' | grep zone_id | awk -F\" '{print $4" "$16" "$20}' | grep -w $domain | awk '{print $1}')
if [ $(echo $1 | grep : | wc -l) == 0 ]
then
	iptype=A
else
	iptype=AAAA
fi
if [ -z "$id" ]
then
	echo "创建域名 $domain $iptype记录"
	curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" -H "Authorization: Bearer $bearer" -H "Content-Type:application/json" --data '{"type":"'"$iptype"'","name":"'"$domain"'","content":"'"$1"'","ttl":1,"proxied":false}'
else
	echo "更新域名 $domain $iptype记录"
	curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$id" -H "Authorization: Bearer $bearer" -H "Content-Type:application/json" --data '{"type":"'"$iptype"'","name":"'"$domain"'","content":"'"$1"'","ttl":1,"proxied":false}'
fi
}

a="$(curl --$ips -s https://www.cloudflare-cn.com/cdn-cgi/trace | grep ip= | cut -f 2- -d'=')"
cloudflaredns $a
while true
do
	sleep 5
	b="$(curl --$ips -s https://www.cloudflare-cn.com/cdn-cgi/trace | grep ip= | cut -f 2- -d'=')"
	if [ "$a" == "$b" ]
	then
		echo "$(date) 公网IP地址 $b 没有发生变化"
	elif [ "$b" != "" ]
	then
		cloudflaredns $b
		while true
		do
			c="$(curl -s "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" -H "Authorization: Bearer $bearer" | sed -e 's/{/\n/g' -e 's/"proxiable"/\n/g' | grep zone_id | awk -F\" '{print $4" "$16" "$20" "$24}' | grep -w $domain | awk '{print $4}')"
			if [ "$b" == "$c" ]
			then
				echo "公网IP更新成功"
				break
			else
				echo "重新请求更新公网IP"
				cloudflaredns $b
			fi
		done
		#这里支持pushplsh微信推送,注释下方curl前面的#号并填写pushplus密钥启用
		#curl --location --request POST 'https://www.pushplus.plus/send' --header 'Content-Type: application/json' --data-raw '{"token":"你的pushplus密钥","title":"公网IP地址已更新","content":"当前公网IP '"$b"'","template":"txt"}'
		a="$b"
	else
		echo "公网IP地址获取失败"
	fi
done
