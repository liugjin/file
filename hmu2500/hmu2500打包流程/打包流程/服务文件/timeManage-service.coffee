###
* File: changeStoreModel-service
* User: foam
* Date: 2020/05/22
* Desc: 
###

# compatible for node.js and requirejs
`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define ['clc.foundation.web', 'child_process'], (base, process) ->
  class TimeManageService extends base.MqttService
    constructor: (options) ->
      super options

    getServiceTime: (callback) -> (
      serviceTime =  new Date()
      callback?(null, {time:serviceTime})
    )
    changeServiceTime: (options, callback) -> (
      process.exec('date -s "' + options.parameters.time + '"')
      serviceTime =  new Date()
      callback?(null, {time: serviceTime})
    )
    saveNTPIP: (options, callback) -> (
      process.exec("ntpdate -u #{options.parameters.ip}")
      serviceTime =  new Date()
      callback?(null, { ntpIp: options.parameters.ip, time: serviceTime })
    )
  exports =
    TimeManageService: TimeManageService
