require 'rubygems'
require 'json'
require 'net/telnet'
require 'pp'

AnsiSetDisplayAttr = '\x1B\[(?>(?>(?>\d+;)*\d+)?)m'
WaitForInput =  '(?>\s+)(?>\x08+)'
AnsiEraseEOL = '\x1B\[K'
AnsiCursorHome = '\x1B\[(?>(?>\d+;\d+)?)H'
PressAnyKey = '\xAB\xF6\xA5\xF4\xB7\x4E\xC1\xE4\xC4\x7E\xC4\xF2'
Big5Code = '[\xA1-\xF9][\x40-\xF0]'
PressAnyKeyToContinue = "#{PressAnyKey}(?>\\s*)#{AnsiSetDisplayAttr}(?>(?:\\xA2\\x65)+)\s*#{AnsiSetDisplayAttr}"
PressAnyKeyToContinue2 = "\\[#{PressAnyKey}\\](?>\\s*)#{AnsiSetDisplayAttr}"
# (b)進板畫面
ArticleList = '\(b\)' + "#{AnsiSetDisplayAttr}" + '\xB6\x69\xAA\x4F\xB5\x65\xAD\xB1\s*' + "#{AnsiSetDisplayAttr}#{AnsiCursorHome}"
Signature = '\xC3\xB1\xA6\x57\xC0\xC9\.(?>\d+).+' + "#{AnsiCursorHome}"

$host = 'ptt.cc'
$board_name = 'Gossiping'
$json_opt_path = '/var/www/index.html'

def connect(port, time_out, wait_time, host)
	tn = Net::Telnet.new(
	'Host'       => host,
	'Port'       => port,
	'Timeout'    => time_out,
	'Waittime'   => wait_time
	)
	return tn
end

def login(tn, id, password)
	tn.waitfor(/guest.+new(?>[^:]+):(?>\s*)#{AnsiSetDisplayAttr}#{WaitForInput}\Z/){ |s| print(s) }
	# 帳號
	tn.cmd("String" => id, "Match" => /\xB1\x4B\xBD\x58:(?>\s*)\Z/){ |s| print(s) }
	# 密碼, 按任意鍵繼續
	tn.cmd("String" => password,
	"Match" => /#{PressAnyKeyToContinue}\Z/){ |s| print(s) }
	tn.print("\n")
end

#進入某板(等於從主畫面按's')
def jump_board(tn, board_name)

	# [呼叫器]
	tn.waitfor(/\[\xA9\x49\xA5\x73\xBE\xB9\]#{AnsiSetDisplayAttr}.+#{AnsiCursorHome}\Z/){ |s| print(s) }
	tn.print('s')
	tn.waitfor(/\):(?>\s*)#{AnsiSetDisplayAttr}(?>\s*)#{AnsiSetDisplayAttr}#{AnsiEraseEOL}#{AnsiCursorHome}\Z/){ |s| print(s) }
	lines = tn.cmd( "String" => board_name, "Match" => /(?>#{PressAnyKeyToContinue}|#{ArticleList})\Z/ ) do |s|
		print(s)
	end

	# 按任意鍵繼續
	if not (/#{PressAnyKeyToContinue}\Z/ =~ lines)
		return lines
	end

	lines = tn.cmd("String" => "", "Match" => /#{ArticleList}\Z/) do |s|
		print(s)
	end
	return lines
end

def gsub_ansi_by_space(s)
	raise ArgumentError, "search_by_title() invalid title:" unless s.kind_of? String

	s.gsub!(/\x1B\[(?:(?>(?>(?>\d+;)*\d+)?)m|(?>(?>\d+;\d+)?)H|K)/) do |m|
		if m[m.size-1].chr == 'K'
			"\n"
		else
			" "
		end
	end
end

def get_article_list(s)
	list = []
	s.scan(/
	# 文章ID
	(?>\s*)(\d+)
	# 推文狀態
	\s+(\+|.|\~|X|x|S|s|\x580)
	# 推文數量
	(?>\s*)(\xC3\x7A|\+\xC3\x7A|s\xC3\x7A|S\xC3\x7A|\s*\d*|' ')
	# 日期
	(?>\s*)(?>\s*)(\d\d\/\d\d|\d\/\d\d|\d\/\d|\d\/\d\d)
	# 帳號
	(?>\s*)(?!(?>\d+\s))(\w{2,})\s+
	# 文章標記
	(?>\s*)(\xA1\xBC|R:|\xC2\xE0)
	# 分類
	(?>\s*)(\[\S*[^\xA4\xBD\xA7\x69]\S*\])
	# 主題
	(?>\s*)(\S*|\S*\s*\S*)
	/x){
		|num, push_stat, push_num, date, author, mark, type, title, d|	list.push("article_id"=>num, "push_stat"=>push_stat, "push_num"=>push_num, "date"=>date, "author"=>author,"mark"=>mark, "type"=>type, "title"=>dash_checker(title) ) # 儲存文章編號與作者帳號 etc...
	}
	return list #(?>\s*)(\S*|#{Big5Code}*|[\x3\xF0]$|\?$|[\xA8\xF6]$)
end

def search_by_title(tn, title)
	tn.print('?')
	tn.waitfor(/\xB7\x6A\xB4\x4D\xBC\xD0\xC3\x44:\s*#{AnsiCursorHome}#{AnsiSetDisplayAttr}\s+#{AnsiSetDisplayAttr}#{AnsiEraseEOL}#{AnsiCursorHome}\Z/){ |s| print(s) }
	result = tn.cmd( 'String' => title, 'Match' => /#{ArticleList}/){ |s| print(s) }
	return result
end

def convert_month(month)
	$m =  month
	case $m
	when 'Jan'
		return 1
	when 'Feb'
		return 2
	when 'Mar'
		return 3
	when 'Apr'
		return 4
	when 'May'
		return 5
	when 'Jun'
		return 6
	when 'Jul'
		return 7
	when 'Aug'
		return 8
	when 'Sep'
		return 9
	when 'Oct'
		return 10
	when 'Nov'
		return 11
	when 'Dec'
		return 12
	else
		return 0
	end
end

#雙斜線會導致輸出的json格式錯誤,所以幹掉他們
def dash_checker(title)
	dash = ''
	title.scan(/(\\\\)/){|d| dash = d}
	return title.delete(dash)
end

def keep_check_board(tn)
	sleep(1)
	tn.print("b")
	sleep(1)
	tn.print("\n")
	sleep(1)

	screen = tn.waitfor(/(?>#{PressAnyKeyToContinue}|#{ArticleList})\Z/){ |s| print(s) }
	result = gsub_ansi_by_space(screen)
	arr = get_article_list(result)
	puts result
	sleep(1)
	dump_json(arr)
	tn.print("\e[4~")
end

def search_by_hot(tn, number)
	tn.print('Z')
	tn.print("#{number}")
	tn.print("\n")
end

def now_time()
	time = Time.new
	return now_time = time.strftime("%Y-%m-%d %H:%M:%S")
end

def page_down()
	tn.print("\e[6~")
end

def dump_json(arr)
	json = JSON.generate(arr)
	pp arr
	puts JSON.pretty_generate(arr)
	puts "\n--------------------\nCount: #{arr.count}  at #{now_time()} \n--------------------\n"
	log(json.delete("\\"), $json_opt_path)
end

def log(log, file_name="index.html")
	File.open("#{file_name}","w+") do |f| f.puts log end
end

def demo_list()
	tn = connect(23, 5, 1, $host)
	login(tn, ARGV[0], ARGV[1])
	result = jump_board(tn, $board_name)
	arr = get_article_list(result)
	#system('cls')
	dump_json(arr)

	while (1)
		keep_check_board(tn)
	end
end

if ARGV.size != 2 then
	print("8gua.rb ID PASSWORD\n")
	exit
end

begin
	# tn = connect(23, 5, 1, "ptt.cc")
	# login(tn, ARGV[0], ARGV[1])
	# result = jump_board(tn, 'Gossiping')
	# result = gsub_ansi_by_space(result)
	# arr = get_article_list(result)
	# system('cls')
	# pp arr

	demo_list()
end


