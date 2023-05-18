require 'typhoeus'
require 'json'
require 'date'
require 'optparse'

def get_user_input_for(variable_name)
  puts "Please, introduce your #{variable_name}"
  gets.chomp
end

options = {}
OptionParser.new do |opt|
  opt.on('-e', '--email EMAIL', 'Woffu user') { |o| options[:email] = o }
  opt.on('-p', '--password PASSWORD', 'Password') { |o| options[:password] = o }
  opt.on('-m', '--fill-empty-presence', 'enable filling presence gaps') { options[:fill_presence] = true }
  opt.on('-s', '--sign', 'enable sign process') { options[:sign] = true }
end.parse!

pass = options[:password] || ENV['WOFFU_PASSWORD']
user = options[:email] || ENV['WOFFU_EMAIL']

user = get_user_input_for("woffu email") if user.nil? || user&.empty?
pass = get_user_input_for("password") if pass.nil? || pass&.empty?

login_response = Typhoeus.get('https://app.woffu.com/token', body: {grant_type: :password, username: user, password: pass})

raise "Unsuccessful login" if login_response.response_code != 200

token = JSON.parse(login_response.body)['access_token']
bearer_token = "Bearer #{token}"

authorization_headers = { authorization: bearer_token }

company_data = Typhoeus.get('https://app.woffu.com/api/companies/companiesbyemail', headers: authorization_headers)
company_data = JSON.parse(company_data.body)

company_id = company_data.first["CompanyId"]

#post
remember_me = Typhoeus.post('https://app.woffu.com/api/users/rememberme', headers: authorization_headers)
remember_me = JSON.parse(remember_me.body)

users = Typhoeus.get('https://app.woffu.com/api/users', headers: authorization_headers)
users = JSON.parse(users.body)
user_id = users["UserId"]
calendar_id = users["Calendar"]["CalendarId"]
department_id = users["DepartmentId"]
job_title_id = users["JobTitleId"]
calendar_id = users["CalendarId"]
schedule_id = users["ScheduleId"]
break_time = 1 #TrueBreakHours

companies = Typhoeus.get("https://app.woffu.com/api/companies/#{company_id}", headers: authorization_headers)
companies = JSON.parse(companies.body)

api_domain = companies["Domain"]
company_id = company_data.first["CompanyId"]
subscription_id = companies["Subscription"]["SubscriptionId"]

company_settings = Typhoeus.get("https://app.woffu.com/api/companies/#{company_id}/settings", headers: authorization_headers)
company_settings = JSON.parse(company_settings.body)

feature_flags = Typhoeus.get("https://app.woffu.com/api/companies/#{company_id}/feature-flags-data", headers: authorization_headers)
feature_flags = JSON.parse(feature_flags.body)

subscription_details = Typhoeus.get("https://app.woffu.com/api/svc/subscriptions/subscription/#{subscription_id}/basic", headers: authorization_headers)
subscription_details = JSON.parse(subscription_details.body)

personal_setup = Typhoeus.get("https://app.woffu.com/api/svc/dashboard/personal/setup", headers: authorization_headers)
personal_setup = JSON.parse(personal_setup.body)

workday_lite = Typhoeus.get("https://#{api_domain}/api/users/#{user_id}/workdaylite", headers: authorization_headers)
workday_lite = JSON.parse(workday_lite.body)

today_time_spans = workday_lite["TimeSpans"]&.map{|e| [e["StartTime"], e["EndTime"]]}

date_yesterday = (Date.today - 1).to_s
date_60_days_ago = (Date.today - 60).to_s

diaries_presence = Typhoeus.get("https://#{api_domain}/api/users/#{user_id}/diaries/presence?fromDate=#{date_60_days_ago}&pageIndex=0&pageSize=100&toDate=#{date_yesterday}", headers: authorization_headers)
diaries = JSON.parse(diaries_presence.body)["Diaries"]

diaries_details = diaries.map{|e| {id: e["DiaryId"], date: e["Date"], hours_to_work: e["HoursToWork"], hours_worked: e["HoursWorked"], true_schedule: e["TrueScheduleHours"], not_categorised: e["HoursNoCategorized"]}}


def get_diary_slots(bearer_token: nil, diary_id: nil)
  diary_slot = Typhoeus.get("https://#{api_domain}/api/diaries/#{diary_id}/workday/slots/self", headers: authorization_headers)
  JSON.parse(diary_slot.body)["Slots"]
end

def generate_diary_entry(sign_id: nil, user_id: nil, date: nil, time: nil, starting: nil)
  { "SignId" => sign_id,
    "UserId" => user_id,
    "Date":"#{date}T#{time}.000",
    "TrueDate":"#{date}T#{time}.000",
    "SignIn" => starting,
    "IP" => nil,
    "Latitude" => nil,
    "Longitude" => nil,
    "Outside" => nil,
    "Time" => time[0..-4],
    "ValueTime" => time,
    "ShortTime" => time,
    "ShortTrueTime" => time,
    "ShortValueTime" => time,
    "UtcTime" => "#{time} +0",
    "Code" => nil,
    "SignType" => 3,
    "SignStatus" => 1,
    "SignEventId" => nil,
    "DeviceId" => nil,
    "DeviceType" => 0,
    "Deleted" => false,
    "ModifiedTime" => time,
    "UpdatedOn" => nil,
    "RequestId" => nil,
    "AgreementEventId" => nil
  }
end

def generate_diary_slot(sign_id: nil, user_id: nil, date: nil, time_start: nil, time_stop: nil, order: nil, total_slot: nil)
  {
    "In" => generate_diary_entry(sign_id: sign_id, user_id: user_id, date: date, time: time_start, starting: true),
    "Out" => generate_diary_entry(sign_id: sign_id, user_id: user_id, date: date, time: time_stop, starting: false),
    "Motive" => nil,
    "isFake" => false,
    "deleted" => false,
    "order" => order,
    "totalSlot" => total_slot
  }
end

authorization_headers_with_content_type = authorization_headers.merge({"content-type" => "application/json;charset=UTF-8"})

def put_diary_slots(authorization_headers: nil, bearer_token: nil, diary_id: nil, user_id: nil, start: nil, break_start: nil, break_stop: nil, stop: nil, department_id: nil, job_title_id: nil, calendar_id: nil, schedule_id: nil, break_time: 1, date: nil, sign_id: 0, api_domain: nil)
  body = {
    "DiaryId" => diary_id,
    "UserId" => user_id,
    "Date" => "#{date}T00:00:00.000",
    "DepartmentId" => department_id,
    "JobTitleId" => job_title_id,
    "CalendarId" => calendar_id,
    "ScheduleId" => schedule_id,
    "AgreementId" => nil,
    "TrueStartTime" => start,
    "TrueEndTime" => stop,
    "TrueBreaksHours" => break_time,
    "Accepted" => false,
    "Comments" => nil,
    "Slots" => [
      generate_diary_slot(sign_id: sign_id, user_id: user_id, date: date, time_start: start, time_stop: break_start, order: 1, total_slot: 5),
      generate_diary_slot(sign_id: sign_id, user_id: user_id, date: date, time_start: break_stop, time_stop: stop, order: 2, total_slot: 3),
    ]
  }

  diary_slot = Typhoeus.put("https://#{api_domain}/api/diaries/#{diary_id}/workday/slots/self", headers: authorization_headers, body: body.to_json)
  raise "Error!! Date: #{date}" if diary_slot.response_code != 204
end

diaries_invalid = diaries_details.reject{|e| e[:hours_to_work] <= e[:hours_worked] || e[:hours_to_work] <= e[:not_categorised]}

diaries_invalid.each do |invalid_diary|
  next unless options[:fill_presence]
  puts invalid_diary
  puts "Diary #{invalid_diary[:date]} will be overriden."

  put_diary_slots(bearer_token: bearer_token, diary_id: invalid_diary[:id], user_id: user_id, start: "09:00:00", break_start: "14:00:00", break_stop: "15:00:00", stop: "18:00:00", department_id: department_id, job_title_id: job_title_id, calendar_id: calendar_id, schedule_id: schedule_id, break_time: break_time, date: invalid_diary[:date].split("T").first, sign_id: 0, authorization_headers: authorization_headers_with_content_type, api_domain: api_domain)
end

def sign_in(authorization_headers: nil, value: false, user_id: nil, api_domain: nil)

  body = {
    "AgreementEventId" => nil,
    "DeviceId" => "WebApp",
    "EndDate" => DateTime.now.to_s,
    "Latitude" => nil,
    "Longitude" => nil,
    "RequestId" => nil,
    "ShortTrueTime" => "09:22:18",
    "StartDate" => DateTime.now.to_s,
    "TimezoneOffset" => "120",
    "UserId" => user_id,
    "signIn" => value
  }

  Typhoeus.post("https://#{api_domain}/api/svc/signs/signs", body: body.to_json, headers: authorization_headers)
end

if today_time_spans && options[:sign]
  sign_in(value: false, user_id: user_id, authorization_headers: authorization_headers_with_content_type, api_domain: api_domain)
end
