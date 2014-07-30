# encoding: UTF-8

require 'restclient'

service 'pushover' do
  action 'notify' do |params|
    message = params['message']
    title   = params['title'] || 'Factor.io'
    user    = params['user']
    token   = params['api_key']

    fail 'Message is required' unless message
    fail 'Title cant be empty' if title.empty?
    fail 'User is required' unless user
    fail 'API Key is required' unless token

    contents = {
      message: message,
      title: title,
      user: username,
      token: token
    }

    info 'Sending message'
    begin
      uri = 'https://api.pushover.net/1/messages.json'
      raw_response = RestClient.post(uri, contents)
      response = JSON.parse(raw_response)
    rescue
      fail 'Failed to send message'
    end
    action_callback response
  end
end