#!/bin/sh

now=`date`

aliddns_ak="AccessKeyId"
aliddns_sk="AccessKeySecret"
aliddns_curl="curl -s http://members.3322.org/dyndns/getip"
aliddns_dns="223.5.5.5"
aliddns_ttl="600"
aliddns_domain="domainname"
aliddns_name="domainrecord"


ip=`$aliddns_curl 2>&1` || die "$ip"

#support @ record nslookup
if [ "$aliddns_name" = "@" ]
then
  current_ip_info=`nslookup $aliddns_domain $aliddns_dns 2>&1`
else
  current_ip_info=`nslookup $aliddns_name.$aliddns_domain $aliddns_dns 2>&1`
fi

#if [ "$?" -eq "0" ]
#then
    current_ip=`echo "$current_ip_info" | grep ^Address | tail -n1 | awk -F\: '{print $NF}' | awk '{print $1}'`

if [ "$ip" = "$current_ip" ]
  then
    echo "skipping"
    exit 0
fi 



timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`

urlencode() {
    # urlencode <string>
    out=""
    while read -n1 c
    do
        case $c in
            [a-zA-Z0-9._-]) out="$out$c" ;;
            *) out="$out`printf '%%%02X' "'$c"`" ;;
        esac
    done
    echo -n $out
}

enc() {
    echo -n "$1" | urlencode
}

send_request() {
    local args="AccessKeyId=$aliddns_ak&Action=$1&Format=json&$2&Version=2015-01-09"
    local hash=$(echo -n "GET&%2F&$(enc "$args")" | openssl dgst -sha1 -hmac "$aliddns_sk&" -binary | openssl base64)
    curl -s "http://alidns.aliyuncs.com/?$args&Signature=$(enc "$hash")"
}

get_recordid() {
    grep -Eo '"RecordId":"[0-9]+"' | cut -d':' -f2 | tr -d '"'
}

query_recordid() {
    send_request "DescribeSubDomainRecords" "SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&SubDomain=$aliddns_name1.$aliddns_domain&Timestamp=$timestamp"
}

update_record() {
    send_request "UpdateDomainRecord" "RR=$aliddns_name1&RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns_ttl&Timestamp=$timestamp&Type=A&Value=$ip"
}

add_record() {
    send_request "AddDomainRecord&DomainName=$aliddns_domain" "RR=$aliddns_name1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns_ttl&Timestamp=$timestamp&Type=A&Value=$ip"
}

#add support */%2A and @/%40 record
case  $aliddns_name  in
      \*)
        aliddns_name1=%2A
        ;;
      \@)
        aliddns_name1=%40
        ;;
      *)
        aliddns_name1=$aliddns_name
        ;;
esac

if [ "$aliddns_record_id" = "" ]
then
    aliddns_record_id=`query_recordid | get_recordid`
fi

if [ "$aliddns_record_id" = "" ]
then
    aliddns_record_id=`add_record | get_recordid`
    echo "added record $aliddns_record_id"
else
    update_record $aliddns_record_id
    echo "updated record $aliddns_record_id"
fi
