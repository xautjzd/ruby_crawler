require 'net/http'
require 'json'
require 'base64'
require 'openssl'

module SimpleHTTP
	def get(uri, hdr=nil)
		uri = URI(uri)
		http = Net::HTTP.new(uri.host, uri.port)

		request = Net::HTTP::Get.new(uri.request_uri)
		request.initialize_http_header(hdr)
		response = http.request(request)
	end   

	def post(uri, hdr)
		uri = URI(uri)
		Net::HTTP.post_form(uri, hdr)
	end
end

class User
	attr_accessor :username, :password, :cookie
	def initialize(username, password)
		@username = username
		@password = password
		@cookie = nil
	end
end


class Login
	include SimpleHTTP
	@@params = %w[SUB SUBP SUS SUE SUP ALF SSOLoginState USRUG]
	@@post_uri = 'http://login.sina.com.cn/sso/login.php?client=ssologin.js(v1.4.18)'

	private
	def utf_decode(txt)
		txt.gsub(/\\u(\h{4})/){ [$1.to_i(16)].pack 'U' }
	end

	def prelogin(username)
		preloginurl = URI('http://login.sina.com.cn/sso/prelogin.php?entry=sso&' + 
											'callback=sinaSSOController.preloginCallBack&su=' +
											username.sub("@", "@") +
											'&rsakt=mod&checkpin=1&client=ssologin.js(v1.4.18)&=' +
											Time.now.to_i.to_s)   
		res = Net::HTTP.get_response(preloginurl)
		puts "state: #{res.message}"
		keys = res.body[/\{"retcode[^\0]*\}/]
		keys = JSON.parse(keys)
	end

	def password_encrypt_rsa(pubkey, pwdkey)
		pub = OpenSSL::PKey::RSA::new
		pub.e = 65537
		pub.n = OpenSSL::BN.new(pubkey, 16)
		res = pub.public_encrypt(pwdkey)
	end

	public
	# 返回登录需要的cookie
	# 带着cookie就能访问需要登录才能访问的页面了
	def login(user)
		return user.cookie if user.cookie

		keys = prelogin(user.username)
		unless keys
			puts "prelogin error!"
			return false
		end
		logindata = { 
			'encoding' => 'UTF-8',
			'entry'=>'weibo',
			'gateway'=>'1',
			'from'=>'',
			'nonce'=>'',
			'prelt'=>'130',
			'pwencode'=>'rsa2',
			'returntype'=>'META',
			'rsakv'=>'',
			'savestate'=>'7',
			'servertime'=>'',
			'service'=>'miniblog',
			'ssosimplelogin'=>'1',
			'sp'=>'',
			'su'=>'',
			'url'=>'http://weibo.com/ajaxlogin.php?framelogin=1&callback=parent.sinaSSOController.feedBackUrlCallBack',
			'userticket'=>'1',
			'vsnf'=>'1',
			'pubkey' => ''
		}
		logindata['servertime'] = keys['servertime']
		logindata['nonce'] = keys['nonce']
		logindata['rsakv'] = keys['rsakv']
		logindata['pubkey'] = keys['pubkey']
		logindata['su'] = Base64.strict_encode64(user.username)

		# encrypt password
		pwdkey = keys['servertime'].to_s + "\t" + keys['nonce'].to_s + "\n" + user.password.to_s
		logindata['sp'] = password_encrypt_rsa(keys['pubkey'], pwdkey).unpack('H*').first

		# post request & get response   
		res = post(@@post_uri, logindata)

		redirecturi = res.body.scan(/location.replace\('(.*?)'\)/)[0][0]
		re_res = get(redirecturi)
		# Get cookie from response
		res_cookie = re_res.header['set-cookie']
		# user.cookie = res_cookie

		cookie = ""
		# 其实这里可以一股脑的全部加进去，不用筛选过
		@@params.each do |param|
			content = res_cookie[/#{param}=.*?;/]
				cookie << content << " " if content
		end
		cookie << "un=#{user.username}"
		user.cookie = cookie.dup
	end
end

username = "89piaoshi@sina.cn"
password = "1207janly"

user = User.new(username, password)
login = Login.new
login.login(user)
puts user.cookie


# uri = URI("http://weibo.com")
#
# res = Net::HTTP.start(uri.host, uri.port) do |http| 
# 	req = Net::HTTP::Get.new(uri, { "Cookie" => user.cookie })
# 	http.request(req)
# end
# puts res.body.to_s[0..5000]
#
