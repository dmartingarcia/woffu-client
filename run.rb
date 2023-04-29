require 'typhoeus'
require 'json'
require 'date'

def get_user_input_for(variable_name)
  puts "Please, introduce your #{variable_name}"
  gets.chomp
end

pass = ENV['WOFFU_PASSWORD']
user = ENV['WOFFU_EMAIL'] 

user = get_user_input_for("woffu email") if user.nil? || user.empty?
pass = get_user_input_for("password") if user.nil? || pass.empty?

login_response = Typhoeus.get('https://app.woffu.com/token', body: {grant_type: :password, username: user, password: pass})

raise "Unsuccessful login" if login_response.response_code != 200

token = JSON.parse(login_response.body)['access_token']
bearer_token = "Bearer #{token}"

company_data = Typhoeus.get('https://app.woffu.com/api/companies/companiesbyemail', headers: {authorization: bearer_token})
company_data = JSON.parse(company_data.body)
company_id = company_data.first["CompanyId"]

#post
remember_me = Typhoeus.post('https://app.woffu.com/api/users/rememberme', headers: {authorization: bearer_token})
remember_me = JSON.parse(remember_me.body)

users = Typhoeus.get('https://app.woffu.com/api/users', headers: {authorization: bearer_token})
users = JSON.parse(users.body)
user_id = users["UserId"]
calendar_id = users["Calendar"]["CalendarId"]
department_id = users["DepartmentId"]
job_title_id = users["JobTitleId"]
calendar_id = users["CalendarId"]
schedule_id = users["ScheduleId"]
break_time = 1 #TrueBreakHours

companies = Typhoeus.get("https://app.woffu.com/api/companies/#{company_id}", headers: {authorization: bearer_token})
companies = JSON.parse(companies.body)
company_id = company_data.first["CompanyId"]
subscription_id = companies["Subscription"]["SubscriptionId"]

company_settings = Typhoeus.get("https://app.woffu.com/api/companies/#{company_id}/settings", headers: {authorization: bearer_token})
company_settings = JSON.parse(company_settings.body)

feature_flags = Typhoeus.get("https://app.woffu.com/api/companies/#{company_id}/feature-flags-data", headers: {authorization: bearer_token})
feature_flags = JSON.parse(feature_flags.body)

subscription_details = Typhoeus.get("https://app.woffu.com/api/svc/subscriptions/subscription/#{subscription_id}/basic", headers: {authorization: bearer_token})
subscription_details = JSON.parse(subscription_details.body)

personal_setup = Typhoeus.get("https://app.woffu.com/api/svc/dashboard/personal/setup", headers: {authorization: bearer_token})
personal_setup = JSON.parse(personal_setup.body)

workday_lite = Typhoeus.get("https://returnly.woffu.com/api/users/#{user_id}/workdaylite", headers: {authorization: bearer_token})
workday_lite = JSON.parse(workday_lite.body)

time_spans = workday_lite["TimeSpans"].map{|e| [e["StartTime"], e["EndTime"]]}

# Nice user tracking that sends deviceid coordinates and some tracking shit, thanks woffu for my privacy
#signs = Typhoeus.get("https://returnly.woffu.com/api/svc/signs/signs", headers: {authorization: bearer_token}, body: {tracking_shit})
#signs = JSON.parse(signs.body)

date_yesterday = (Date.today - 1).to_s
date_60_days_ago = (Date.today - 60).to_s

diaries_presence = Typhoeus.get("https://returnly.woffu.com/api/users/#{user_id}/diaries/presence?fromDate=#{date_60_days_ago}&pageIndex=0&pageSize=100&toDate=#{date_yesterday}", headers: {authorization: bearer_token})
diaries = JSON.parse(diaries_presence.body)["Diaries"]

diaries_details = diaries.map{|e| {id: e["DiaryId"], date: e["Date"], hours_to_work: e["HoursToWork"], hours_worked: e["HoursWorked"], true_schedule: e["TrueScheduleHours"], not_categorised: e["HoursNoCategorized"]}}


def get_diary_slots(bearer_token: nil, diary_id: nil)
  diary_slot = Typhoeus.get("https://returnly.woffu.com/api/diaries/#{diary_id}/workday/slots/self", headers: {authorization: bearer_token})
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

def put_diary_slots(bearer_token: nil, diary_id: nil, user_id: nil, start: nil, break_start: nil, break_stop: nil, stop: nil, department_id: nil, job_title_id: nil, calendar_id: nil, schedule_id: nil, break_time: 1, date: nil, sign_id: 0)
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
    
  diary_slot = Typhoeus.put("https://returnly.woffu.com/api/diaries/#{diary_id}/workday/slots/self", headers: {authorization: bearer_token, "content-type" => "application/json;charset=UTF-8"}, body: body.to_json)
  raise "Error!! Date: #{date}" if diary_slot.response_code != 204
end

diaries_invalid = diaries_details.reject{|e| e[:hours_to_work] == e[:hours_worked] || e[:hours_to_work] == e[:not_categorised]}

puts "Everything set as expected! ;)" if diaries_invalid.empty?

diaries_invalid.each do |invalid_diary|
  puts invalid_diary
  puts "Diary #{invalid_diary[:date]} will be overriden. [y/n]"
  input = gets
  next if input.chomp != "y"
  
  put_diary_slots(bearer_token: bearer_token, diary_id: invalid_diary[:id], user_id: user_id, start: "09:00:00", break_start: "14:00:00", break_stop: "15:00:00", stop: "18:00:00", department_id: department_id, job_title_id: job_title_id, calendar_id: calendar_id, schedule_id: schedule_id, break_time: break_time, date: invalid_diary[:date].split("T").first, sign_id: 0)
end
