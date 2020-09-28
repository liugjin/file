###
* File: service-register
* User: Pu
* Date: 2018/9/1
* Desc: 
###

# compatible for node.js and requirejs
`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define ['clc.foundation',
  'clc.foundation.web',
  './datacenter-service',
  './backupInfo-service',
  './getVersion-service',
  './timeManage-service'
], (base, web, cs, bis, gvs, tms) ->
  class ServiceRegister extends base.ServiceRegisterBase
    constructor: (options, namespace) ->
      super options, namespace

    createService: (name) ->
      switch name
        when 'register'
          service = new web.RegisterService @getOptions 'register'
        when 'configuration'
          service = new web.ConfigurationService @getOptions 'configuration'
        when 'home'
          service = new web.HomeService @options
        when 'datacenter'
          service = new cs.DatacenterService @getOptions('services')
        when 'TimeManageService'
          service = new tms.TimeManageService @getOptions('services')
        when 'BackupInfo'
          service = new bis.BackupInfoService @getOptions('services')
        when 'GetVersionService'
          service = new gvs.GetVersionService @getOptions('services')
        else
          throw "unsupported service: #{name}"

      service


  exports =
    ServiceRegister: ServiceRegister
