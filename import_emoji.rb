require 'mechanize'
require 'open-uri'
require 'json'

# Class to get emoji data from target slack team and upload emoji to
# destination slack team
#
class SlackEmoji
  # variables
  # file names
  ConfigFile = 'emoji_conf.txt'
  DefaultFile = 'default_emoji.txt'
  EmojiFile = 'emoji.txt'
  LogFile = 'emoji_log.txt'
  # messages to judge upload was success or fail
  LoginFail = "Sorry, you entered an incorrect email address or password"
  AddSuccess = "Your new emoji has been saved"
  DuplicateEmoji = 'There is already an emoji named'
  # Slack emoji list API
  ApiUrl = 'https://slack.com/api/emoji.list?pretty=1&token='

  # variables from config file
  @@url = ''
  @@email = ''
  @@password = ''
  @@token = ''

  # default emoji
  @@default = nil # default emoji set
  # emoji JSON
  @@hash = nil

  # Login to Slack team and upload all emoji by using Mechanize
  #
  # @return int -1 error
  #              0 success 
  def uploadEmoji()
    log_file = open(LogFile, 'wb')
    agent = Mechanize.new
    agent.user_agent = 'Windows Mozilla'

    # login to Slack team
    agent.get(@@url) do |page|
      response = page.form_with(:action => '/') do |form|
        formdata = {
          :email => @@email, # login mail address
          :password => @@password # login @@password
        }
        form.field_with(:name => 'email').value = formdata[:email]
        form.field_with(:name => 'password').value = formdata[:password]
      end.submit

      # if login fails, write error to log file and exit
      if response.code != '200' || response.body.include?(LoginFail)
        log_file.write("Login failed! Please check Slack url, email and password.\n")
        return -1
      end
      log_file.write("Login success!\n")

      # loop upload emoji
      @@hash.each do |node|
        name = File.basename(node[1])
        agent.get(@@url + 'customize/emoji') do |emoji|
          if File.exist?('./' + name)
            eresponse = emoji.form_with(:action => '/customize/emoji') do |eform|
              eform.field_with(:name => 'name').value = node[0]
              eform.radiobuttons_with(:name => 'mode')[0].check
              eform.file_upload_with(:name => 'img').file_name = './' + name
            end.submit
	    # write result to log
	    # check responce code and body to decide success or failer
            if eresponse.code != '200' # check 
              log_file.write("F Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
              log_file.write("Respose code is not 200. Failed to add emoji.\n")
            elsif eresponse.body.include?(AddSuccess) # add success log
              log_file.write("S Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
              log_file.write("Successfully added.\n")
            elsif eresponse.body.include?(DuplicateEmoji) # add error log - duplicate error
              log_file.write("F Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
              log_file.write("Same emoji name already exist.\n")
            else # add error log - unknown error
              log_file.write("F Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
              log_file.write("Unknown error occured.\n")
            end
          else # add error log - file not found
            log_file.write("F Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
            log_file.write("File not exist.\n")
          end
        end
        sleep 3 # wait 3 seconds for slack server
      end
    end
    return 0 # success
  end

  # Get team emoji text from Web API by JSON format
  #
  def getEmojiText
    open(EmojiFile, 'wb') do |output|
      open(ApiUrl + @@token) do |data|
        output.write(data.read)
      end
    end
  end

  # Download emoji file from URL
  # must call readEmojiJSON before call this function
  def getEmojiData
    @@hash.each do |node| # loop each node
      name = File.basename(node[1]) # get file name from URL
      if name !~ /^alias/
        open(name, 'wb') do |output|
          open(node[1]) do |data|
            output.write(data.read) # write to local
          end
        end
      end
      sleep 3
    end
  end

  # Read emoji text and load to JSON
  #
  def readEmojiJSON
    File.open(EmojiFile, 'r') do |file|
      @@hash = JSON.load(file)
    end

    @@hash = @@hash['emoji']
    @@hash.each do |node|
      if !@@default.index(node[0]).nil? || node[1] =~ /^alias/
        @@hash.delete(node[0])
      end
    end
  end

  # Read config file
  #
  def readConfigFile
    config = Array.new
    File.open(ConfigFile, 'r') do |file|
      file.each_line do |line|
        stripLine = line.strip
        if stripLine !~ /^#/ && !stripLine.empty?
          config.push(line.strip)
        end
      end
    end
    @@url = config[0] # target slack team URL 
    @@email = config[1] # email to login
    @@password = config[2] # password
    @@token = config[3] # target slack team token 
  end

  # read default emoji file
  # some emoji are default, so need skip those
  def readDefaultEmojiFile
    @@default = Array.new
    File.open(DefaultFile, 'r') do |file|
      file.each_line do |line|
        stripLine = line.strip
        if stripLine !~ /^#/ && !stripLine.empty?
          @@default.push(line.strip)
        end
      end
    end
  end
end

# create object
emoji = SlackEmoji.new

# read config and default files
emoji.readConfigFile
emoji.readDefaultEmojiFile

# get emoji text from target slack team
emoji.getEmojiText
# read emoji file
emoji.readEmojiJSON
# get all emoji data
emoji.getEmojiData
# upload emoji data
emoji.uploadEmoji

