require 'rubygems'
require 'json'
require 'net/telnet'
require 'pp'
require 'iconv'

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
$json_opt_path = '/var/www/8gua/index.html'

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
	(?>\s*)(?>\s*)(\d*\/\d+)
	# 帳號
	(?>\s*)(?!(?>\d+\s))(\w{2,})\s+
	# 文章標記
	(?>\s*)(\xA1\xBC|R:|\xC2\xE0)
	# 分類
	(?>\s*)(\[\S*\])
	# 主題
	(?>\s*)(.*)
	/x){
		|num, push_stat, push_num, date, author, mark, type, title, d|	list.push(
		"article_id"=> num, 
		"push_stat"=> big5_2_utf8(push_stat), 
		"push_num"=> push_num, 
		"date"=> date, 
		"author"=> big5_2_utf8(author),
		"mark"=> big5_2_utf8(mark), 
		"type"=> big5_2_utf8(type), 
		"title"=> big5_2_utf8(mine_checker(title.gsub(/\xA1\xB9.*/,''))))
	}
	return list 
end

def search_by_title(tn, title)
	tn.print('?')
	tn.waitfor(/\xB7\x6A\xB4\x4D\xBC\xD0\xC3\x44:\s*#{AnsiCursorHome}#{AnsiSetDisplayAttr}\s+#{AnsiSetDisplayAttr}#{AnsiEraseEOL}#{AnsiCursorHome}\Z/){ |s| print(s) }
	result = tn.cmd( 'String' => title, 'Match' => /#{ArticleList}/){ |s| print(s) }
	return result
end

def big5_2_utf8(data) #@!!! Iconv::InvalidCharacter
	begin
	ic = Iconv.new("utf-8//IGNORE","big5")
	data = ic.iconv(data.to_s)
	rescue
		pute "\n iconv error \n"
	ensure
		return  data
	end
end

def mine_checker(data)
	return data.delete("\\\\").to_s.gsub(/"/, "'")
end

def keep_check_board(tn)
	sleep(1)
	tn.print("b")
	sleep(1)
	tn.print("\n")
	sleep(1)

	result = tn.waitfor(/(?>#{PressAnyKeyToContinue}|#{ArticleList})\Z/){ |s| print(s) }
	result = line_me(result)
	result = gsub_ansi_by_space(result)
	puts result
	arr = get_article_list(result)
	dump_json(arr)
	tn.print("\e[4~")
end

def now_time()
	time = Time.new
	return now_time = time.strftime("%Y-%m-%d %H:%M:%S")
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

def line_me(s)
	s.gsub!(/\d\d\d\d\d/) do |m|
		"\n#{m}"
	end

end

def demo_list()
	tn = connect(23, 5, 1, $host)
	login(tn, ARGV[0], ARGV[1])
	result = jump_board(tn, $board_name)
	result = line_me(result)
	result = gsub_ansi_by_space(result)
	puts result
	arr = get_article_list(result)
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
	demo_list()
end


