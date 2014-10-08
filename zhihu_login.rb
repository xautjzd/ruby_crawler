require 'rubygems'
require 'mechanize'

agent = Mechanize.new
# Get page object
login_page = agent.get "http://www.zhihu.com/#signin/"

# Get form object
login_form = login_page.forms[0]

# Fill out form(username and password)
email_field = login_form.field_with(:name => "email")
email_field.value = "your username here"
password_field = login_form.field_with(:name => "password")
password_field.value = "your_password here"

# Get the page after login success
success_page = agent.submit login_form

# Get cookie
tmp_cookie = agent.cookie_jar
puts tmp_cookie

index_page = agent.get "http://www.zhihu.com"
puts index_page.body.to_s[0..5000]
