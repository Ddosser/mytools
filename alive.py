#!/usr/bin/env python
#coding:utf-8

import requests
import ConfigParser
from time import sleep
import time 


def main():
    cf = ConfigParser.ConfigParser()
    cf.read("./scripts.conf")

    
    s = requests.Session()
    url_list = [
        cf.get("url", "url1"),
        cf.get("url", "url2"),
        cf.get("url", "url3"),
        cf.get("url", "url4"),
        cf.get("url", "url5"),
        cf.get("url", "url6"),
    ]


    while True:
        t = time.localtime(time.time())
        print time.strftime("%H:%M:%S", t)
        for url in url_list:
            if not url:
                continue
            try:
                req = s.get(url = url, timeout = 10)
                if req.status_code == 200:
                    print "\033[32m [+] {}\033[m".format(url)
                else:
                    print "\033[31m [-] {}\033[m".format(url)
            except:
                print "\033[31m [-] {}\033[m".format(url)

        sleep(30)


if __name__ == "__main__":
    main()
