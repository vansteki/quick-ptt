##簡介

demo site: [http://djw.twbbs.org/8gua/] (http://djw.twbbs.org/8gua/)

這是一隻用來爬PTT 八卦板的爬蟲，此為簡易版，目前能擷取文章列表(輸出格式為JSON)。

順便一提，這位大大的範例帶給我不少幫助，想玩Ruby + telnet 的人一定要來看看　ＸＤ

http://godspeedlee.myweb.hinet.net/

##Ruby 版本
ruby 1.8.7 (2012-02-08 patchlevel 358) [i686-linux]
  
##使用方法
  
    gem install json
  
    ruby 8gua.rb [PTT帳號] [密碼]

登入成功後就會開始跳至八卦板爬文了! enjoy it :)

##注意事項!

###使用Ruby1.9.X 要注意檔案utf8的問題 和 [正規表示要修改] (http://goo.gl/FQr2W)

  檔案utf8的問題: 請在檔案最上方插入此行　
     
    #encoding: utf-8

###請勿使用本程式於非法行為，此程式僅供教學研究用途。


##Introduction

A crawer use Ruby net/telnet to fetch article list of board 'Gossiping' of PTT.CC. (4Chat.com of Taiwan)

JSON outputed. 

##Ruby Version

ruby 1.8.7 (2012-02-08 patchlevel 358) [i686-linux]

##How to use?

    gem install json
  
    ruby 8gua.rb [your PTT ID] [PASS]

enjoy it :)
    
##Notice!

If you use Ruby1.9.X , you may have to fix some problem:

###UTF-8 problem:

Write this line on top of that file

    #encoding: utf-8
  
sudo gem install magic_encoding, then just call magic_encoding from the root of your app.

  
###regular expression problem
  
http://goo.gl/FQr2W

####
  This project is only for education and research. Do not abuse it on illegal behavior.
      
