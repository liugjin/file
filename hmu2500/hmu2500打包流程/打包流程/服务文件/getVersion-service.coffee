###
* File: getStoreModel-service
* User: foam
* Date: 2020/05/22
* Desc: 
###

# compatible for node.js and requirejs
`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define [
  'clc.foundation.web',
  'fs'
], (base, fs) ->
  class GetVersionService extends base.MqttService
    constructor: (options) ->
      super options

    getVersion: (callback) => (
      pageFile = JSON.parse(fs.readFileSync("./package.json"))
      if(fs.existsSync("./version.json"))
        versionFile =  JSON.parse(fs.readFileSync("./version.json"))
        result = {
          appVersion: pageFile.version,
          hardwareVersion: versionFile.hardwareVersion,
          systemVersion: versionFile.systemVersion,
          tag: versionFile.tag
        }
        callback?(null, result)
      else
        result = {
          appVersion: pageFile.version,
          hardwareVersion: "",
          systemVersion: "",
          tag: ""
        }
        callback?(null, result)
    )
  exports =
    GetVersionService: GetVersionService
