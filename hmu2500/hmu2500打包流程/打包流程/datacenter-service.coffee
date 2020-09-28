###
* File: datacenter-service
* User: Pu
* Date: 2018/9/1
* Desc: 
###

# compatible for node.js and requirejs
`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define [
  'ftp',
  'moment'
  'clc.foundation.web',
  'iced-coffee-script',
  'adm-zip',
  '../../../index-setting',
  'path',
  'fs',
  'underscore',
  'child_process'], ( ftp, moment, base, iced, zip, setting, path, fs, _, process) ->
  iced = iced.iced if iced.iced

  class DatacenterService extends base.RpcService
    constructor: (options) ->
      super options


      sm = require "./service-manager"
      @TimeManageService = sm.getService "TimeManageService"
      @BackupInfoService = sm.getService "BackupInfo"
      @GetVersionService = sm.getService "GetVersionService"

    initializeProcedures: ->
      @registerProcedure [
        'echo',
        'upload',
        "ipSetting",
        "muSetting",
        "changeStoreMode",
        "getStoreMode",
        "changeStoreInfo",
        "getVersionInfo",
        "getServiceTime",
        "changeServiceTime",
        "saveNTPIP"
      ]

    # you can define any methods for rpc
    echo: (options,callback) ->
      time = options.parameters.time + " -- server: #{new Date().toISOString()}"
      result =
        time: time

      callback? null, result

    upload: (file, callback) ->
#      file = Buffer.from options.parameters.file, "base64"
      zp = new zip file.path
#      entries = zp.getEntries()
      text = zp.readAsText("component.json")
      js = zp.readAsText("component.js")
      result = "error"
      if text and js
        component = JSON.parse text
        if component.id and component.version and js.indexOf("BaseDirective")>0
          result = "ok"
          src = path.join __dirname, "../../scripts/", setting.id, "/src/"
          main = fs.readFileSync src+"main.js"
          plugins = JSON.parse fs.readFileSync src+"directives/plugins.json"
          if main.indexOf("directives/"+component.id+"/component") < 0
            plugin = _.find plugins, (item)->item.id is component.id
            if not plugin
              plugins.push {id: component.id}
              fs.writeFileSync src+"directives/plugins.json", JSON.stringify plugins
          zp.extractAllTo src+"directives/"+component.id, true
      callback null, result

    ipSetting: (options, callback) ->
      if options.action is "get"
        defaultData =
          type: 'static'
          ip: '127.0.0.1'
          mask: '255.255.255.0'
          gateway: '192.168.0.1'
          dns: ''
        @networkPath = "/etc/network/interfaces"
#        @networkPath = "D:/interfaces"
        if fs.existsSync @networkPath
          @file = (fs.readFileSync @networkPath).toString()
          @network = @file.split(/[\n\r]/)
          @data =
            type: @operateText @network, "iface eth0 inet"
            ip: @operateText @network, "address"
            mask: @operateText @network, "netmask"
            gateway: @operateText @network, "gateway"
            dns: @operateText @network, "dns-nameserver"
        callback? null, @data ? defaultData
      else if options.action is "post"
        setting = options.parameters
        @operateText @network, "iface eth0 inet", setting.type if setting.type
        @operateText @network, "address", setting.ip if setting.ip
        @operateText @network, "netmask", setting.mask if setting.mask
        @operateText @network, "gateway", setting.gateway if setting.gateway
        @operateText @network, "dns-nameserver", setting.dns if setting.dns
        fs.writeFileSync @networkPath, @file if fs.existsSync @networkPath
        if setting.type is "static"
          process.exec "ifconfig eth0 "+setting.ip+" netmask "+setting.mask if setting.ip isnt @data.ip or setting.mask isnt @data.mask
          process.exec "route add default gw "+setting.gateway if setting.gateway and setting.gateway isnt @data.gateway
        callback null, "ok"

    operateText: (arr, key, value) ->
      item = _.find arr, (it)->it.indexOf(key)>=0
      return null if not item
      keys = item.trim().split " "
      if not value?
        return keys[keys.length-1]
      else
        keys[keys.length-1] = value
        news = keys.join " "
        @file = @file.replace item, news

    muSetting: (options, callback) ->
      if options.action is "get"
        @muPath = "/root/apps/app/aggregation/monitoring-units.json"
#        @muPath = "D:/projects/clc.mu/monitoring-units.json"
        @elementPath = "/root/apps/app/aggregation/element-lib/"
#        @elementPath = "D:/projects/clc.mu/cfg/custom-elements/"
        if fs.existsSync @muPath
          @muInfo = JSON.parse (fs.readFileSync @muPath).toString()
          @elements = {}
          for element in fs.readdirSync @elementPath
            @elements[element.split(".")[0]] = JSON.parse (fs.readFileSync @elementPath+element).toString()
          callback? null, {mu: @muInfo, elements: @elements}
      else if options.action is "post"
        mu = options.parameters
        fs.writeFileSync @muPath, JSON.stringify mu if fs.existsSync @muPath
        process.exec "pm2 restart start_aggregation"
        callback? null, "ok"
    # 修改储存策略
    changeStoreMode: (options, callback) => (
      @BackupInfoService.changeStoreMode(options, callback)
    )
    # 获取储存策略和数据备份
    getStoreMode: (options, callback) => (
      # @GetStoreModelService.run(callback)
      @BackupInfoService.getStoreMode(callback)
    )
    # 修改储存信息
    changeStoreInfo: (options, callback) => (
      @BackupInfoService.changeStoreInfo(options, callback)
    )
    # 获取版本信息
    getVersionInfo: (options, callback) => (
      @GetVersionService.getVersion(callback)
    )
    # 获取服务器时间
    getServiceTime: (options, callback) => (
      @TimeManageService.getServiceTime(callback)
    )
    # 修改服务器时间
    changeServiceTime: (options, callback) => (
      @TimeManageService.changeServiceTime(options, callback)
    )
    # 保存saveNTP服务器的IP
    saveNTPIP: (options, callback) => (
      @TimeManageService.saveNTPIP(options, callback)
    )
  exports =
    DatacenterService: DatacenterService
