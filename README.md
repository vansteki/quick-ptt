##Introduction
A crawler use Ruby net/telnet to fetch article list of board  of PTT.CC. (4Chat.com of Taiwan)

JSON outputed. 

[demo site] (http://djw.twbbs.org/quick-ptt/Gossiping.html)

##Ruby Version
ruby 1.8.7 (2012-02-08 patchlevel 358) [i686-linux]

##Require
    gem install json
    gem install iconv

##Usage
    ruby daemon.rb [PTT ID] [PTT PASS] [board name(optional, default: Gossiping)]
    ruby daemon.rb guest guest C_Chat  #let's fetch C_Chat board :) 

    then you can see something like below
    --------------------
    Count: 18  at 2013-02-04 17:22:25
    --------------------

    --------------------
    Count: 18  at 2013-02-04 17:22:29
    --------------------
    ...
    
    view result
    http://127.0.0.1/quick-ptt/[board name].html
    
    http://127.0.0.1/quick-ptt/Gossiping.html
    or
    http://127.0.0.1/quick-ptt/C_Chat.html
    
    

##Config
    $host             host IP/domain name       
    $json_opt_path    Output path and file name, default: ./index.html　

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
      
