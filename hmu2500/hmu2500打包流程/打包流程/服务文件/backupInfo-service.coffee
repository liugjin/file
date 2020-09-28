###
* File: backupInfo-service
* User: foam
* Date: 2020/05/22
* Desc: 
###

# compatible for node.js and requirejs
`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define [
  'clc.foundation.web',
  'clc.foundation.data/app/models/configuration/equipment-signals-model',
  'clc.foundation.data/app/models/monitoring/event-values-model',
  'clc.foundation.data/app/models/monitoring/signal-values-model',
  'clc.foundation.data/app/models/monitoring/signal-statistics-model',
  'moment',
  'ftp',
  'later',
  'fs'
], (base, esm, eventService, signalService, statisticsService, moment, ftp, later, fs) ->
  class BackupInfoService extends base.MqttService
    constructor: (options) ->
      super options

      @eventService = new eventService.EventValuesModel
      @signalService = new signalService.SignalValuesModel
      @statisticsService = new statisticsService.SignalStatisticsModel
      @equipmentSignalsService = new esm.EquipmentSignalsModel
      @init()
    # 初始化执行的函数,自动执行
    init: () => (
      @settingPath = "./store-setting.json"
      if(fs.existsSync(@settingPath))
        @setting = JSON.parse(fs.readFileSync(@settingPath))
        @ftpHost = @setting.ftpHost
        @ftpPort = Number(@setting.ftpPort)
        @ftpUser = @setting.ftpUser
        @ftpPassword = @setting.ftpPassword
        @user = @setting.user
        @project = @setting.project
        @setUploadTime()
      else
        console.log("无数据转储路径")
    )
    # 指定每天凌晨12点上传
    setUploadTime: () => (
      timing = { schedules: `[{h:[00],m:[00]}]` }
      later.date.localTime()
      everydayExecute = later.setInterval(()=>
        @queryStoreSheet()
      , timing);

    )
    # 查询singale-values,event-values和statistics-Values表并上传
    queryStoreSheet: () => (
      @signalService.find({ user: @user, project: @project}
      # @signalService.find({ user: @user, project: @project, station: "center-qianjiang", equipment: "pd-3"}
        null,
        (err1, signalValues) => (
          @uploadFtp(signalValues, "signalValues")
          @eventService.find({  user: @user, project: @project}
          # @eventService.find({  user: @user, project: @project, station: "center-qianjiang", equipment: "pd-3"}
            null,
            (err2, eventValues) => (
              @uploadFtp(eventValues, "eventValues")
              @statisticsService.find({ user: @user, project: @project}
              # @statisticsService.find({ user: @user, project: @project, station: "center-qianjiang", equipment: "pd-3"}
                null,
                (err3, statisticsValues) => (
                  @uploadFtp(statisticsValues, "statisticsValues")
                )
              )
            )
          )
        )
      )
    )
    # 上传文件到ftp,一次上传需要实例化一个对象,并且需要重新连接,否则会报错
    uploadFtp: (arrValues, fileName) => (
      nowTime = moment(new Date()).format("YYYYMMDD")
      FTP = new ftp()
      str = JSON.stringify(arrValues, fileName)
      buf = Buffer.from(str)
      FTP.on("error", (err)=>
        console.log {status: false, msg: "数据备份时发生错误,备份失败"}
      )
      FTP.on("ready", ()->
        FTP.put(buf, "#{nowTime}-#{fileName}.json", (err)->
          throw err if err
          FTP.end()
        )
      )
      FTP.connect(
        {
          host: @ftpHost,
          port: Number(@ftpPort),
          user: @ftpUser,
          password: @ftpPassword
        }
      )
    )
    # 修改当前ftp地址的信息
    changeStoreInfo: (options, callback) => (
      FTP = new ftp()
      FTP.on("error", (err)=>
        return callback?(null, {status: false, msg: "连接失败"})
      )
      FTP.on("ready", ()=>
        @setting.ftpHost = @ftpHost = options.parameters.address.host
        @setting.ftpPort = @ftpPort = Number(options.parameters.address.port)
        @setting.ftpUser = @ftpUser = options.parameters.address.user
        @setting.ftpPassword = @ftpPassword = options.parameters.address.password
        @setting.project = @project = options.parameters.project
        @setting.user = @user = options.parameters.user
        fs.writeFileSync(@settingPath, JSON.stringify(@setting))
        @init()
        callback?(null, {status: true, msg: "连接成功"})
      )
      FTP.connect(
        {
          host: options.parameters.address.host,
          port: Number(options.parameters.address.port),
          user: options.parameters.address.user,
          password: options.parameters.address.password
        }
      )
    )
    # 修改储存模式
    changeStoreMode: (options,callback) => (
      @equipmentSignalsService.model.update(
        { user: options.parameters.user, project: options.parameters.project, storage:{ $ne: null } },
        { $set: { storage: { period: parseInt(options.parameters.model) } } },
        { multi: true },
        (err, data) => (
          if(fs.existsSync("./store-setting.json"))
            @setting = JSON.parse(fs.readFileSync("./store-setting.json"))
            @setting.storeMode = options.parameters.model
            fs.writeFileSync("./store-setting.json", JSON.stringify(@setting))
            callback?(null, data)
          else
            console.log("无store-setting.json文件,修改储存模式失败")
            callback?(null, {status: false, msg: "修改储存模式失败"})
        )
      )
    )
    # 获取储存策略和数据备份的ftp地址
    getStoreMode: (callback) => (
      if(fs.existsSync("./store-setting.json"))
        @setting = JSON.parse(fs.readFileSync("./store-setting.json"))
        result = {
          host: @setting.ftpHost,
          port: @setting.ftpPort,
          user: @setting.ftpUser,
          password: @setting.ftpPassword,
          storeMode: @setting.storeMode
        }
        callback?(null, result)
      else
        obj = {
          host:"",
          port:null,
          user:"",
          password:"",
          user:"",
          storeMode:"",
        }
        callback?(null, obj)
)
  exports =
    BackupInfoService: BackupInfoService
