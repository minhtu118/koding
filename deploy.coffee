#!/usr/bin/env coffee

AWS        = require 'aws-sdk'
AWS_DEPLOY_KEY    = require("fs").readFileSync("#{__dirname}/install/keys/aws/koding-prod-deployment.pem")
AWS.config.region = 'us-east-1'
AWS.config.update accessKeyId: 'AKIAI7RHT42HWAA652LA', secretAccessKey: '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'

argv       = require('minimist')(process.argv.slice(2))
eden       = require 'node-eden'
log        = console.log
timethat   = require 'timethat'
Connection = require "ssh2"
fs         = require 'fs'
ec2        = new AWS.EC2()
elb        = new AWS.ELB()
class Deploy

  @connect = (options,callback) ->
    {IP,username,password,retries,timeout} = options

    options.retry = yes unless options.retrying

    conn = new Connection()

    listen = (prefix, stream, callback)->
      _log = (data) -> log ("#{prefix} #{data}").replace("\n","") unless data or data is ""
      stream.on          "data", _log
      stream.stderr.on   "data", _log
      stream.on "close", callback
      # stream.on "exit", (code, signal) -> log "[#{prefix}] did exit."

    sftpCopy = (options, callback)->
      copyCount = 1
      results = []
      options.conn.sftp (err, sftp) ->
        for file,nr in options.files
          do (file)->
            sftp.fastPut file.src,file.trg,(err,res)->
              if err
                log "couldn't copy:",file
                throw err
              log file.src+" is copied to "+file.trg
              if copyCount is options.files.length then callback null,"done"
              copyCount++

    conn.connect
      host         : IP
      port         : 22
      username     : username
      privateKey   : AWS_DEPLOY_KEY
      readyTimeout : timeout


    conn.on "ready", ->
      conn.listen   = listen
      conn.sftpCopy = sftpCopy
      callback null,conn

    conn.on "error", (err) -> retry()


    retry = ->
      if options.retries > 1
        options.retries = options.retries-1
        log "connecting to instance.. attempts left:#{options.retries}"
        setTimeout (-> Deploy.connect options, callback),timeout
      else
        log "not retrying anymore.", options.retries
        callback "error connecting."

  @createInstance = (options={}, callback) ->

    # Creates a new instance and returns a live connection.
    buildNumber  = options.buildNumber  or 1113
    instanceName = options.instanceName or "prod-#{buildNumber}-#{eden.eve().toLowerCase()}"

    params = options.params or
      ImageId       : "ami-a6926dce" # Amazon ubuntu 14.04 "ami-1624987f" # Amazon Linux AMI x86_64 EBS
      InstanceType  : "t2.micro"
      MinCount      : 1
      MaxCount      : 1
      SubnetId      : "subnet-b47692ed"
      KeyName       : "koding-prod-deployment"

    iamcalledonce = 0

    start = new Date()

    ec2.runInstances params, (err, data) ->
      iamcalledonce++
      if iamcalledonce > 1 then return log "i am called #{iamcalledonce} times"
      if err
        # log "\n\nCould not create instance ---->", err
        log """code:#{err.code},name:#{err.name},code:#{err.statusCode},#{err.retryable}
         ---
         [ERROR] #{err.message}
        \n\n
        """
        return
      else
        instanceId = data.Instances[0].InstanceId
        log "-----> Created instance", instanceId

        # Add tags to the instance
        params =
          Resources: [instanceId]
          Tags: [
            Key   : "Name"
            Value : instanceName
          ]

        ec2.createTags params, (err) ->
          log "-----> Tagged with #{instanceName}", (if err then "failure" else "success")

          params =
            InstanceIds : [instanceId]

          states =
            initialState  : null
            instanceState : null
            reachability  : null
          __ = setInterval ->

            unless states.initialState is "running" or states.instanceState is "running"

              ec2.describeInstanceStatus params,(err,data)->
                if err then log err
                else
                  states.instanceState = data?.InstanceStatuses?[0]?.InstanceState?.Name
                  states.reachability  = data?.InstanceStatuses?[0]?.InstanceStatus?.Details?[0]?.Status

              ec2.describeInstances params,(err,data)->
                if err then log err
                else
                  states.initialState = data?.Reservations?[0]?.Instances?[0]?.State?.Name
                  states.final        = data?.Reservations?[0]?.Instances?[0]
            else
              log "instance is now running with IP:", IP = states.final.PublicIpAddress
              clearInterval __

              Deploy.connect IP: IP, username: "ubuntu", retries: 30, timeout: 5000, (err,conn)->
                unless err
                  log "creating #{instanceName} took "+ timethat.calc start,new Date()
                  conn.exec "uptime;",(err, stream)->

                    return log err  if err
                    conn.listen "-->", stream,->
                      log "connection established... preparing the box."
                      conn.final = states.final

                      res =
                        conn : conn
                        instanceData : states.final
                        instanceName : instanceName
                        buildOptions : options

                      callback null, res
                else
                  log "ignoring err callback", err

          ,5000

  @deployAndConfigure = (options,callback)->

    options = options or
      params :
        ImageId       : "ami-1624987f" # Amazon ubuntu 14.04 "ami-1624987f" # Amazon Linux AMI x86_64 EBS
        InstanceType  : "t2.medium"
        # InstanceType  : "t2.micro"
        MinCount      : 1
        MaxCount      : 1
        SubnetId      : "subnet-b47692ed"
        KeyName       : "koding-prod-deployment"
      buildNumber     : 1113
      instanceName    : null



    Deploy.createInstance options,(err,result) ->
      deployStart = new Date()
      {conn} = result

      KONFIG = require("./config/main.prod.coffee")
        hostname : result.instanceName

      cmd = """
        echo '#{new Buffer(KONFIG.runFile).toString('base64')}' | base64 --decode > /tmp/run.sh;
        sudo bash /tmp/run.sh install;
        sudo bash /opt/koding/run services;
        sudo service supervisor restart
        \n
        """

      cmd = "echo hello world"

      conn.exec cmd, (err, stream) ->
        log 4
        throw err if err
        conn.listen "[configuring #{result.instanceName}]", stream,->
          log 5
          throw err if err
          # delete result.conn
          # log result.instanceData
          log "Deployment of #{result.instanceName} took: "+timethat.calc deployStart,new Date()
          conn.end()
          callback null, result

# module.exports = Deploy


Deploy.deployAndConfigure null,(err,res)->
  log "#{res.instanceName} is ready."
  log "Box is ready at mosh root@#{res.instanceData.PublicIpAddress}"


class Release

  works = ->
    elb.deregisterInstancesFromLoadBalancer
      Instances        : [{ InstanceId: 'i-dd310cf7' }]
      LoadBalancerName : "koding-prod-deployment"
    ,(err,res) ->
      log err,res


    elb.registerInstancesWithLoadBalancer
      Instances        : [{ InstanceId: 'i-dd310cf7' }]
      LoadBalancerName : "koding-prod-deployment"
    ,(err,res) ->
      log err,res


    elb.describeInstanceHealth
      Instances        : [{ InstanceId: 'i-dd310cf7' }]
      LoadBalancerName : "koding-prod-deployment"
    ,(err,res)->
      log err,res

  @fetchLoadBalancerInstances = (LoadBalancerName,callback)->
    elb.describeLoadBalancers LoadBalancerNames : [LoadBalancerName],(err,res)->
      log res.LoadBalancerDescriptions[0].Instances

    ec2.describeInstances {},(err,res)->

  fetchInstancesWithPrefix = (prefix,callback)->

    pickValueOf= (key,array) -> return val.Value if val.Key is key for val in array
    instances = []
    ec2.describeInstances {},(err,res)->
      # log err,res
      for r in res.Reservations
        a = InstanceId: r.Instances[0].InstanceId, Name: pickValueOf "Name",r.Instances[0].Tags
        b = InstanceId: r.Instances[0].InstanceId
        instances.push b if a.Name.indexOf(prefix) > -1
      # log instances
      callback null,instances

  @registerInstancesWithPrefix = (prefix, callback)->
    fetchInstancesWithPrefix prefix, (err,instances)->
      # log instances
      elb.registerInstancesWithLoadBalancer
        Instances        : instances
        LoadBalancerName : "koding-prod-deployment"
      ,callback

  @deregisterInstancesWithPrefix = (prefix, callback)->
    fetchInstancesWithPrefix prefix, (err,instances)->
      log instances
      elb.deregisterInstancesFromLoadBalancer
        Instances        : instances
        LoadBalancerName : "koding-prod-deployment"
      ,callback




release = (key)->
  Release.registerInstancesWithPrefix key,(err,res)->
    log res
    log ""
    log ""
    log "------------------------------------------------------------------------------"
    log "#{key} is now deployed and live with bazillion instances."
    log "------------------------------------------------------------------------------"

rollback = (key)->
  Release.deregisterInstancesWithPrefix key,(err,res)->
    log res
    log ""
    log ""
    log "------------------------------------------------------------------------------"
    log "#{key} is now rolled back. All instances are taken out of rotation."
    log "------------------------------------------------------------------------------"


if argv.release
  release argv.release

if argv.rollback
  rollback argv.rollback


# "use strict"
# inquirer = require "inquirer"
# console.log "Hi, welcome to Koding Deployment Tool"
# questions = [
#   {
#     type: "list",
#     name: "theme",
#     message: "What do you want to do?",
#     choices: [
#       "Deploy a version",
#       "Run tests",
#       "Switch koding.com",

#       new inquirer.Separator(),
#       "Ask opening hours",
#       "Talk to the receptionnist"
#     ]
#   }
#   {
#     type: "confirm"
#     name: "toBeDelivered"
#     message: "Is it for a delivery"
#     default: false
#   }
#   {
#     type: "input"
#     name: "phone"
#     message: "What's your phone number"
#     validate: (value) ->
#       pass = value.match(/^([01]{1})?[\-\.\s]?\(?(\d{3})\)?[\-\.\s]?(\d{3})[\-\.\s]?(\d{4})\s?((?:#|ext\.?\s?|x\.?\s?){1}(?:\d+)?)?$/i)
#       if pass
#         true
#       else
#         "Please enter a valid phone number"
#   }
#   {
#     type: "list"
#     name: "size"
#     message: "What size do you need"
#     choices: [
#       "Large"
#       "Medium"
#       "Small"
#     ]
#     filter: (val) ->
#       val.toLowerCase()
#   }
#   {
#     type: "input"
#     name: "quantity"
#     message: "How many do you need"
#     validate: (value) ->
#       valid = not isNaN(parseFloat(value))
#       valid or "Please enter a number"

#     filter: Number
#   }
#   {
#     type: "expand"
#     name: "toppings"
#     message: "What about the toping"
#     choices: [
#       {
#         key: "p"
#         name: "Peperonni and chesse"
#         value: "PeperonniChesse"
#       }
#       {
#         key: "a"
#         name: "All dressed"
#         value: "alldressed"
#       }
#       {
#         key: "w"
#         name: "Hawaïan"
#         value: "hawaian"
#       }
#     ]
#   }
#   {
#     type: "rawlist"
#     name: "beverage"
#     message: "You also get a free 2L beverage"
#     choices: [
#       "Pepsi"
#       "7up"
#       "Coke"
#     ]
#   }
#   {
#     type: "input"
#     name: "comments"
#     message: "Any comments on your purchase experience"
#     default: "Nope, all good!"
#   }
#   {
#     type: "list"
#     name: "prize"
#     message: "For leaving a comments, you get a freebie"
#     choices: [
#       "cake"
#       "fries"
#     ]
#     when: (answers) ->
#       answers.comments isnt "Nope, all good!"
#   }
# ]

# inquirer.prompt questions, (answers) ->
#   console.log "\nOrder receipt:"
#   console.log JSON.stringify(answers, null, "  ")
#   return
