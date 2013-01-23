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
RepeatLogin = "\xAD\xAB\xBD\xC6\xB5\x6E\xA4\x4A.*\[Y\/n\]"


$host = 'ptt.cc'
$board_name = 'Gossiping'
$json_opt_path = 'C:\xampp-portable\htdocs\index.html'
$pre_result = ''
$iconv_fail = 0

def connect(port, time_out, wait_time, host)
	tn = Net::Telnet.new(
	'Host'       => host,
	'Port'       => port,
	'Timeout'    => time_out,
	'Waittime'   => wait_time
	)
	return tn
end


$check_relogin
def login(tn, id, password)

	tn.waitfor(/guest.+new(?>[^:]+):(?>\s*)#{AnsiSetDisplayAttr}#{WaitForInput}\Z/){ |s| print(s) }
	# 帳號
	tn.cmd("String" => id, "Match" => /\xB1\x4B\xBD\x58:(?>\s*)\Z/){ |s| print(s) }
	# 密碼, 按任意鍵繼續
	tn.cmd("String" => password,
	"Match" => /#{PressAnyKeyToContinue}\Z/){ |s|
		print(s)
		if $check_relogin == 'yes'
			kick_self_off(tn)
		end
	}
	tn.print("\n")
end

def kick_self_off(tn)
	if tn.waitfor(/.*\xAA\x60\xB7\x4E\:.*/){ |s| print(s) }
		tn.print('Y')
		tn.print("\n")
		tn.print("\n")
		jump_board(tn, $board_name)
		keep_check_board(tn)
	end
end

#進入某板(等於從主畫面按's')
def jump_board(tn, board_name)
	puts "\n jump_board() \n"
	# [呼叫器]
	tn.waitfor(/(\[\xA9\x49\xA5\x73\xBE\xB9\])#{AnsiSetDisplayAttr}.+#{AnsiCursorHome}\Z/){ |s|  } #print(s)
	tn.print('s')
	tn.waitfor(/\):(?>\s*)#{AnsiSetDisplayAttr}(?>\s*)#{AnsiSetDisplayAttr}#{AnsiEraseEOL}#{AnsiCursorHome}\Z/){ |s|  } #print(s)
	lines = tn.cmd( "String" => board_name, "Match" => /(?>#{PressAnyKeyToContinue}|#{ArticleList})\Z/ ) do |s|
		print(s)
	end

	# 按任意鍵繼續
	if not (/#{PressAnyKeyToContinue}\Z/ =~ lines)
		return lines
	end

	lines = tn.cmd("String" => "", "Match" => /#{ArticleList}\Z/) do |s|
		#print(s)
	end
	return lines
end

def gsub_ansi_by_space(s)
	begin
		s.gsub!(/\x1B\[(?:(?>(?>(?>\d+;)*\d+)?)m|(?>(?>\d+;\d+)?)H|K)/) do |m|
			if m[m.size-1].chr == 'K'
				"\n"
			else
				" "
			end
		end
	rescue
		puts "\n----gsub_ansi_by_space erro: ---\n #{s} \n"
	end
end

def get_article_list(s)
	list = []
	begin
		s.scan(/
		# 文章ID
		(?>\s*)(\d*)
		# 推文狀態
		\s+(\+|.|\~|X|x|S|s|\x580)
		# 推文數量
		(?>\s*)(\xC3\x7A|\+\xC3\x7A|s\xC3\x7A|S\xC3\x7A|\s*\d*|' ')
		# 日期
		(?>\s*)(?>\s*)(\d+\/\d+)
		# 帳號
		(?>\s*)(?!(?>\d+\s))(\w{2,})\s+
		# 文章標記
		(?>\s*)(\xA1\xBC|R:|\xC2\xE0)
		# 分類
		(?>\s*)(\[\S*[^\xA4\xBD\xA7\x69]\S*\])
		# 主題
		(?>\s*)(.*)
		/x){
			|articleID, pushStatus, pushCount, date, author, mark, type, title|
			title = mine_checker(title)
			fullLIst = articleID + ' ' + pushStatus + ' ' + pushCount + ' ' + date + ' ' + 	author + ' ' + mark + ' ' + type + ' ' + title

			list.push(
			"fullLIst"=> big5_2_utf8(fullLIst),
			"articleID"=> articleID,
			"pushStatus"=> big5_2_utf8(pushStatus),
			"pushCount"=> big5_2_utf8(pushCount),
			"date"=> date,
			"author"=> big5_2_utf8(author),
			"mark"=> big5_2_utf8(mark),
			"type"=> big5_2_utf8(type),
			"title"=> big5_2_utf8(title)
			)
		}
	rescue
		puts 'get_article_list error'
	ensure
		return list
	end
end

def bottom(tn)
	tn.print("\e[4~")
end

def big5_2_utf8(data) #@!!! Iconv::InvalidCharacter
	begin
		ic = Iconv.new("utf-8//IGNORE","big5")
		data = ic.iconv(data.to_s)
		$iconv_fail = 0
	rescue
		puts "\n iconv error \n"
		$iconv_fail = 1
	ensure
		return  data
	end
end

def mine_checker(data)
	return data.delete("\\\\").to_s.gsub(/"/, "'").gsub(/\xA1\xB9.*/,'')
end

def now_time()
	time = Time.new
	return now_time = time.strftime("%Y-%m-%d %H:%M:%S")
end

def dump_json(arr)
	json = JSON.generate(arr)
	#pp arr
	#puts JSON.pretty_generate(arr)
	puts "\n--------------------\nCount: #{arr.count}  at #{now_time()} \n--------------------\n"
	if arr.count >= 16 && arr.count <= 20 &&$iconv_fail == 0
		$pre_result = json
		log(json, $json_opt_path)
	else
		log($pre_result, $json_opt_path)
	end
end

def log(log, file_name="index.html")
	File.open("#{file_name}","w+") do |f| f.puts log end
end

def line_me(s)
	s.gsub!(/[^\w*]\d{5,}[^\w*]/) do |m|
		"\n#{m}"
	end
end

def keep_check_board(tn)
	while (1)
		sleep(1)
		tn.print("b")
		sleep(1)
		tn.print("\n")
		sleep(1)

		result = tn.waitfor(/(?>#{PressAnyKeyToContinue}|#{ArticleList})\Z/){ |s| } #print(s)
		result = gsub_ansi_by_space(result)
		result = line_me(result)
		#puts result
		arr = get_article_list(result)
		dump_json(arr)
		bottom(tn)	#to bottom
	end
end

def crawer_ini()
	begin
		$check_relogin = 'no'
		tn = connect(23, 10, 1, $host)
		login(tn, ARGV[0], ARGV[1])
		result = jump_board(tn, $board_name)
		result = gsub_ansi_by_space(result)
		result = line_me(result)
		puts result
		arr = get_article_list(result)
		dump_json(arr)
		keep_check_board(tn)
	rescue
		puts "\n crawer_ini faild \n"
		crawer_retry_mode()
	end
end

def crawer_retry_mode()
	begin
		$check_relogin = 'yes'
		tn = connect(23, 10, 1, $host)
		login(tn, ARGV[0], ARGV[1])
		result = jump_board(tn, $board_name)
		result = gsub_ansi_by_space(result)
		result = line_me(result)
		puts result
		arr = get_article_list(result)
		dump_json(arr)
		keep_check_board(tn)
	rescue
		sleep(3)
		puts "\n retry faild \n"
		retry
	end
end

if ARGV.size != 2 then
	print("8gua.rb ID PASSWORD\n")
	exit
end

begin
	crawer_ini()
end