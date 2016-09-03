require 'mechanize'
require 'open-uri'
require 'json'

class SlackEmoji
  # variables
  ConfigFile = 'emoji_conf.txt'
  DefaultFile = 'default_emoji.txt'
  EmojiFile = 'emoji.txt'
  LogFile = 'emoji_log.txt'
  LoginFail = "Sorry, you entered an incorrect email address or password"
  AddSuccess = "Your new emoji has been saved"
  DuplicateEmoji = 'There is already an emoji named'
  ApiUrl = 'https://slack.com/api/emoji.list?pretty=1&token=' # Slack emoji list API
  @@url = '' # Slack team URL to import emoji
  @@email = ''
  @@password = ''
  @@token = ''
  @@default = nil # default emoji set
  @@hash = nil

  def uploadEmoji()
    log_file = open(LogFile, 'wb')
    agent = Mechanize.new
    agent.user_agent = 'Windows Mozilla'
    agent.get(@@url) do |page|
      response = page.form_with(:action => '/') do |form|
        formdata = {
          :email => @@email, # login mail address
          :password => @@password # login @@password
        }
        form.field_with(:name => 'email').value = formdata[:email]
        form.field_with(:name => 'password').value = formdata[:password]
      end.submit

      if response.code != '200' || response.body.include?(LoginFail)
        log_file.write("Login failed! Please check Slack url, email and password.\n")
        return -1
      end
      log_file.write("Login success!\n")

      @@hash.each do |node|
        name = File.basename(node[1])
        agent.get(@@url + 'customize/emoji') do |emoji|
          if File.exist?('./' + name)
            eresponse = emoji.form_with(:action => '/customize/emoji') do |eform|
              eform.field_with(:name => 'name').value = node[0]
              eform.radiobuttons_with(:name => 'mode')[0].check
              eform.file_upload_with(:name => 'img').file_name = './' + name
            end.submit
            if eresponse.code != '200'
              log_file.write("F Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
              log_file.write("Respose code is not 200. Failed to add emoji.\n")
            elsif eresponse.body.include?(AddSuccess)
              log_file.write("S Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
              log_file.write("Successfully added.\n")
            elsif eresponse.body.include?(DuplicateEmoji)
              log_file.write("F Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
              log_file.write("Same emoji name already exist.\n")
            else
              log_file.write("F Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
              log_file.write("Unknown error occured.\n")
            end
          else
            log_file.write("F Name:[" + node[0] + "] FileName:[" + name + "] Result: ")
            log_file.write("File not exist.\n")
          end
        end
        sleep 3
      end
    end
  end

  def getEmojiText
    open(EmojiFile, 'wb') do |output|
      open(ApiUrl + @@token) do |data|
        output.write(data.read)
      end
    end
  end

  def getEmojiData()
    @@hash.each do |node|
      name = File.basename(node[1])
      if name !~ /^alias/
        open(name, 'wb') do |output|
          open(node[1]) do |data|
            output.write(data.read)
          end
        end
      end
      sleep 3
    end
  end

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
    @@url = config[0]
    @@email = config[1]
    @@password = config[2]
    @@token = config[3]
  end

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


emoji = SlackEmoji.new

emoji.readConfigFile
emoji.readDefaultEmojiFile

emoji.getEmojiText
emoji.readEmojiJSON
emoji.getEmojiData
emoji.uploadEmoji

