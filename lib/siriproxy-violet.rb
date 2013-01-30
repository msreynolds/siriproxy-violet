########################################################################################################################
# Mountain Labs, LLC
# mtnlabs.com
# Author: Matthew Reynolds
# matt at mtnlabs dot com
# Indigo Violet SiriProxy plugin 1.0 beta for controlling your Indigo Home Automation server
########################################################################################################################

require 'cora'
require 'siri_objects'
require 'pp'
require 'addressable/uri'
require 'net/http'
require 'net/http/digest_auth'

class SiriProxy::Plugin::Violet < SiriProxy::Plugin

  # This plugin's current version number
  VIOLET_VERSION = '1.0 beta'

  ##  Pick something that is:
  #1) the most common spelling of an actual name or word
  #2) a name or word that is easy to recognize and has a sharp pronunciation (violet does not work well)
  BOT_NAME = 'Indigo Violet'

  # Indigo Host (address and port of your Indigo Restful Interface)
  INDIGO_WEB_SERVER = 'http://192.168.0.5:8176'

  # Indigo Digest Auth properties
  INDIGO_REALM = 'Indigo Control Server'
  INDIGO_USER = 'indigo'
  INDIGO_PASSWORD = 'indigo'

  INDIGO_SPRINKLER_DEVICE = 'irrmasterpro'
  INDIGO_THERMOSTAT_DEVICE = 'thermostat'

  def initialize(config)
    #process custom configuration options here!
  end

  #############################################################
  # Methods
  #############################################################

  # Create a device uri string
  # Return the device uri string
  def get_device_url(device_name)
    device_url = '/devices/'+device_name
    device_url = Addressable::URI.parse(device_url).normalize.to_str
    device_url
  end

  # Create an instance of URI
  # Return the URI instance
  def get_device_uri(device_name)
    device_url = INDIGO_WEB_SERVER + get_device_url(device_name)
    device_uri = Addressable::URI.parse(device_url)
    device_uri.user = INDIGO_USER
    device_uri.password = INDIGO_PASSWORD
    device_uri
  end

  # Create an action group uri string
  # Return the action group uri string
  def get_action_group_url(action_group_name)
    action_group_url = '/actions/'+action_group_name+'?_method=execute'
    action_group_url = Addressable::URI.parse(action_group_url).normalize.to_str
    action_group_url
  end

  # Create an instance of URI
  # Return the URI instance
  def get_action_group_uri(action_group_name)
    action_group_url = INDIGO_WEB_SERVER + get_action_group_url(action_group_name)
    action_group_uri = Addressable::URI.parse(action_group_url)
    action_group_uri.user = INDIGO_USER
    action_group_uri.password = INDIGO_PASSWORD
    action_group_uri
  end

  # Clean the quotes from the algorithm=\"MD5\" in the original http_response's www-authenticate string
  # The spec does not include quotes in this flag, having them can cause issues
  # http://stackoverflow.com/questions/10770478/unknown-algorithm-md5-using-net-http-digest-auth
  def cleanAlgorithmAttribute(www_auth_string)
    www_auth_string["algorithm=\"MD5\""] = "algorithm=MD5"
    www_auth_string
  end

  # Create and send an authenticated HTTP Get call
  # Return the HTTP Response
  def do_authenticated_get(indigo_uri)
    http = Net::HTTP.new indigo_uri.host, indigo_uri.port
    #http.set_debug_output $stderr

    # Make initial request that should produce a 401 Unauthorized
    # The 401 Unauthorized response contains important auth information,
    # bits of which are used later to create an authorized session
    http_request = Net::HTTP::Get.new indigo_uri.request_uri
    http_response = http.request http_request

    # Support for Digest Authentication
    digest_auth = Net::HTTP::DigestAuth.new

    # Construct the appropriate Authentication header string
    auth = digest_auth.auth_header indigo_uri, cleanAlgorithmAttribute(http_response['www-authenticate']), 'GET'

    # Create the new GET request with the proper Authorization header
    http_request = Net::HTTP::Get.new indigo_uri.request_uri
    http_request.add_field 'Authorization', auth

    # Make the second (authenticated) call, return the http response
    http.request http_request
  end

  # Create and send an authenticated HTTP PUT call
  # Return the HTTP Response
  def do_authenticated_put(indigo_uri, body)
    http = Net::HTTP.new indigo_uri.host, indigo_uri.port
    #http.set_debug_output $stderr

    # Make initial request that should produce a 401 Unauthorized
    # The 401 Unauthorized response contains important auth information,
    # bits of which are used later to create an authorized session
    http_request = Net::HTTP::Get.new indigo_uri.request_uri
    http_response = http.request http_request

    # Support for Digest Authentication
    digest_auth = Net::HTTP::DigestAuth.new

    # Construct the appropriate Authentication header string
    auth = digest_auth.auth_header indigo_uri, cleanAlgorithmAttribute(http_response['www-authenticate']), 'PUT'

    # Create the new PUT request with the proper Authorization header
    http_request = Net::HTTP::Put.new indigo_uri.request_uri
    http_request.content_type = 'multipart/form-data'
    http_request.set_form_data(body)
    http_request.add_field 'Authorization', auth

    # Make the second (authenticated) call, return the http response
    http.request http_request
  end

  # Create a string response to send back to the user, given the HTTP response from the indigo web server
  # Return the string
  def get_bot_response(http_response)
    case http_response.code
      when "303"
        "Ok"
      when "401"
        "I am unauthorized"
      when "200"
        "I am unable to find that device"
      when "404"
        "I am unable to find the automation system"
      else
        "I received an unknown response from the automation system"
    end
  end


  #############################################################
  # Filters
  #############################################################

  #get the user's location and display it in the logs
  #filters are still in their early stages. Their interface may be modified
  filter "SetRequestOrigin", direction: :from_iphone do |object|
    puts "[Info - User Location] lat: #{object["properties"]["latitude"]}, long: #{object["properties"]["longitude"]}"

    #Note about returns from filters:
    # - Return false to stop the object from being forwarded
    # - Return a Hash to substitute or update the object
    # - Return nil (or anything not a Hash or false) to have the object forwarded (along with any
    #    modifications made to it)
  end

  ## Get the device's unique Siri ID so we know who's making the request.
  #filter "LoadAssistant", direction: :from_iphone do |object|
  #  @assistantId = object["properties"]["assistantId"]
  #  puts "[Info - Assistant ID: #{@assistantId}"


  #############################################################
  # Listen Control Phrases
  #############################################################

  listen_for /test siri proxy/i do
    # standard test
    say "You may call me "+BOT_NAME
    request_completed
  end

  listen_for /test #{BOT_NAME}/i do
    # custom test
    begin
      devices_url = INDIGO_WEB_SERVER + '/devices.xml'
      devices_uri = Addressable::URI.parse(devices_url)
      devices_uri.user = INDIGO_USER
      devices_uri.password = INDIGO_PASSWORD
      http_response = do_authenticated_get(devices_uri)
      case http_response.code
        when "401"
          status = "Unauthorized"
        when "200"
          status = "Ready"
        when "404"
          status = "Unable to find the automation system"
        else
          status = "Unable to negotiate with the automation system"
      end
      say 'Indigo Violet plugin ' + VIOLET_VERSION + ' for SiriProxy. System Status: '+status
    rescue Exception=>e
      puts e.exception
    ensure
      request_completed
    end
  end

  listen_for /hello #{BOT_NAME}/i do
    # standard greeting
    say 'Hello.'
    request_completed
  end

  #Turn On
  listen_for /turn on(?: the)? ([a-z 1-9]*)/i do |device_name|
    device_name.strip!
    begin
      device_uri = get_device_uri(device_name)
      http_response = do_authenticated_put(device_uri, {"isOn" => "True"})
      say get_bot_response(http_response)
    rescue Exception=>e
      puts e.exception
    ensure
      request_completed
    end
  end

  #Turn Off
  listen_for /turn off(?: the)? ([a-z 0-9]*)/i do |device_name|
    device_name.strip!
    begin
      device_uri = get_device_uri(device_name)
      http_response = do_authenticated_put(device_uri, {"isOn" => "False"})
      say get_bot_response(http_response)
    rescue Exception=>e
      puts e.exception
    ensure
      request_completed
    end
  end

  #Execute
  listen_for /execute ([a-z 0-9]*)/i do |action_group_name|
    action_group_name.strip!
    begin
      action_group_uri = get_action_group_uri(action_group_name)
      http_response = do_authenticated_get(action_group_uri)
      say get_bot_response(http_response)
    rescue Exception=>e
      puts e.exception
    ensure
      request_completed
    end
  end

  #Thermostat
  listen_for /set(?: the)? thermostat to ([0-9]*[0-9])/i do |degrees|
    degrees.strip!
    begin
      device_uri = get_device_uri(INDIGO_THERMOSTAT_DEVICE)
      http_response = do_authenticated_put(device_uri, {"setpointHeat" => degrees})
      say get_bot_response(http_response)
    rescue Exception=>e
      puts e.exception
    ensure
      request_completed
    end
  end

  #Sprinklers
  listen_for /([a-z]*)(?: the)? sprinklers/i do |action|
    action.strip!
    begin
      if (action =~ /pause/i or action =~ /resume/i)
        device_uri = get_device_uri(INDIGO_SPRINKLER_DEVICE)
        http_response = do_authenticated_put(device_uri, {"activeZone" => action})
        say get_bot_response(http_response)
      else
        say "I don't understand that sprinkler action request"
      end
    rescue Exception=>e
      puts e.exception
    ensure
      request_completed
    end
  end

  #Brightness
  listen_for /set(?: the)? ([a-z 0-9]*) brightness to ([0-9]*[0-9])(?: percent)?/i do |device_name, dim_value|
    device_name.strip!
    dim_value.strip!
    begin
      device_uri = get_device_uri(device_name)
      http_response = do_authenticated_put(device_uri, {"brightness" => dim_value})
      say get_bot_response(http_response)
    rescue Exception=>e
      puts e.exception
    ensure
      request_completed
    end
  end

  #Toggle
  listen_for /toggle(?: the)? ([a-z 1-9]*)/i do |device_name|
    device_name.strip!
    begin
      device_uri = get_device_uri(device_name)
      http_response = do_authenticated_put(device_uri, {"toggle" => "1"})
      say get_bot_response(http_response)
    rescue Exception=>e
      puts e.exception
    ensure
      request_completed
    end
  end

end
