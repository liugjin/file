###
* File: datacenter-map-directive
* User: David
* Date: 2019/01/18
* Desc:
###

# compatible for node.js and requirejs
`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define ['async!baidu-map','../base-directive','text!./style.css', 'text!./view.html', 'underscore', "moment",'echarts', 'echarts-map/js/china', 'echarts-bmap'], (BMap2,base, css, view, _, moment, echarts) ->
  class DatacenterMapDirective extends base.BaseDirective
    constructor: ($timeout, $window, $compile, $routeParams, commonService)->
      @id = "datacenter-map"
      super $timeout, $window, $compile, $routeParams, commonService
      @datacenterMapSub = null
      @stationAlarmSub = {}
      @selectStationObjs = {}

    setScope: ->

    setCSS: ->
      css

    setTemplate: ->
      view

    show: ($scope, element, attrs) =>
      return if not $scope.firstload 
      $scope.equipAlarmSubs = {}
      $scope.geoEquipObjs = {}
      $scope.managementType = '_station_management'
      $scope.managementTemplate = '_station_management_template'
      $scope.legendPrefix = 'legend-'
      filter =
        type: $scope.managementType
        template: $scope.managementTemplate
      # initialize map
      if @$routeParams.project.indexOf("campus") >= 0
        $scope.parameters.mapdataType = "equipment"

      initializeMapOptions = ()=>
        $scope.mapOptions =
          title: $scope.project.model.name
  #          subTitle: $scope.project.model.name
  #        subLink: "#/dashboard/#{@project.model.user}/#{@project.model.project}"
  #            stations: stationResults
          project: $scope.project
          valueType: $scope.signalType
          mapType: $scope.project.model.map
          equipsData:[]
          stationsData:[]
        
        if $scope.parameters.mapdataType is "equipment"
          $scope.mapOptions.valueType = {type:"_alarms",name:"告警数量"}
          @getEquipsData($scope)
        else
          @getStationsData($scope)
          @getEquipsData($scope)

      selectValueType = (type={})->
        $scope.signalType = type
        $scope.valueType = type?.type
        initializeMapOptions()

      cb = (type,err,tempalte) =>
        selectValueType type
        callback? err,tempalte

      $scope.project?.loadEquipmentTemplate filter, null, (err, template) =>
        template.loadSignals null, (err, signals) =>
          return cb() if not signals?.length
          # initialize value types based on template signals
          types = {}
          for signal in signals
            type =
              type: signal.model.signal
              name: signal.model.name
            types[signal.model.signal] = type
          $scope.valueTypes = types
          template.loadProperties null, (err, properties) =>
            return cb() if not properties.length
            # initialize value legend
            for p in properties
              id = p.model.property
              if p.model.value and id.indexOf($scope.legendPrefix) == 0
                id = id.substr $scope.legendPrefix.length
                type = $scope.valueTypes[id]

                if type
                  type.legend = JSON.parse p.model.value
                  return cb types[type.type],err,template

            return cb types[signals[0].model.signal], err ,template

      option = null
      bmap = null
      $scope.mychart = null
# ①初始化图表
      initializeChart = () =>
        $scope.mychart?.dispose()
        e = element.find('.datacenter-map')
        $scope.mychart = echarts.init(e[0])

        $scope.mychart.on 'click', (params) =>
          return if not params.data
          if params.componentType is 'series'
            if params.data.type is "station"
              if $scope.project.model.project == "iiot-cable"
                @$window.location.href = "#/stationinfo-tongxin/#{@$routeParams.user}/#{@$routeParams.project}?station=#{params.data.id}"
              else
                @$window.location.href = "#/huaen-boxlist/#{@$routeParams.user}/#{@$routeParams.project}?station=#{params.data.id}"

          clearTimeout $scope.timer if $scope.timer
          $scope.timer = setTimeout(()->
            data =
              key: params.data.key
              name: params.name
              event: 'click'
            selectStation(data)
  #          $scope.selectStation?()? data
          ,250)

        $scope.mychart.on 'dblclick', (params) ->
          return if not params.data
          clearTimeout $scope.timer if $scope.timer
          data =
            key: params.data.key
            name: params.name
            event: 'dblclick'
          selectStation(data)
#          $scope.selectStation?()? data

      initializeChart()

      selectStation=(data)=>
        if data.event == 'dbclick'
          @commonService.publishEventBus 'dbclickStation',data
        else
          @commonService.publishEventBus 'clickStation',data

##② 订阅站点选择站点事件 让地图定位到站点经纬度
      @datacenterMapSub?.dispose()
      @datacenterMapSub = @commonService.subscribeEventBus 'select-station', (d) ->
        model = d.message?.model
        if bmap and model?.longitude
          bmap.panTo new BMap.Point model.longitude, model.latitude

##③监听地图数据 由controller里传过来的数据，
      $scope.$watch('mapOptions.stationsData', (data) ->
        console.log("datadata1",data)
        return if not data

        # clean baidu map
        if bmap and $scope.mapOptions.mapType isnt 'bmap'
          bmap = null
          initializeChart()

        #        mychart?.clear()
        option = createChartOption $scope.mapOptions
        $scope.mychart.setOption option, true

        bmap = initializeBaiduMap $scope.mychart if option.bmap
      , true)

      $scope.$watch('mapOptions.equipsData', (data) ->
        console.log("datadata2",data)
        return if not data

        # clean baidu map
        if bmap and $scope.mapOptions.mapType isnt 'bmap'
          bmap = null
          initializeChart()

        #        mychart?.clear()
        option = createChartOption $scope.mapOptions
        $scope.mychart.setOption option, true

        bmap = initializeBaiduMap $scope.mychart if option.bmap
      , true)



      createPieces = (valueType) ->
        pieces = []

        if valueType.legend
          min = -1
          max = 0
          for l in valueType.legend
            min = max
            max = l.value

            pieces.push
              min: min
              max: max
              label: l.name
              color: l.color
        pieces
#
      createChartOption = (options) ->
        valueType = options.valueType
        pieces = createPieces valueType

        # geo or bmap
        mapType = options.mapType ? 'geo'

        option =
    #      backgroundColor: '#404a59'
          title:
            text: options.title
            subtext: options.subTitle
            sublink: options.subLink
            left: 'center'
            textStyle: color: '#757575'
          tooltip:
            trigger: 'item'
            formatter: (params) ->
#              "#{params.name}: #{params.value[2]}"
              res = "<span style='color:#ccff43;'>" + params.name + "</span><br/><span style='color:#ccff43;'>告警数：" + params.value[2] + "</span>";
              return res;
#            position: (point, params, dom, rect, size)->
#              #其中point为当前鼠标的位置，size中有两个属性：viewSize和contentSize，分别为外层div和tooltip提示框的大小
#              x = 0
#              y = 0
#
#              # 当前鼠标位置
#              pointX = point[0]
#              pointY = point[1]
#
#              #提示框大小
#              boxWidth = size.contentSize[0]
#              boxHeight = size.contentSize[1]
#
#              #boxWidth > pointX 说明鼠标左边放不下提示框
#              if (boxWidth > pointX)
#                x = 5
#              else
#                x = pointX - boxWidth - (dom.offsetLeft - rect.x)
#
#              if (boxHeight > pointY)
#                y = 5
#              else
#                y = pointY - boxHeight - (dom.offsetTop - rect.y)
#              console.info "x:" + x + ",y:" + y
#              console.info "rx:" + rect.x + ",ry:" + rect.y
#              return [x, y]


          toolbox:
            show: true
            orient: 'vertical'
            top: 'middle'
            feature:
              dataView: readOnly: false
              restore: false
              saveAsImage: {}
          legend:
            orient: 'vertical'
            y: 'top'
            x: 'left'
            data: [ valueType.name ]
            textStyle:
              color: '#757575'
          visualMap: [
            {
              type: 'piecewise'
              left: 10
              bottom: 60
              pieces: pieces
              textStyle:
                color: '#757575'
            }
          ]
    #      geo:
    #        map: 'china'
    #        label: emphasis: show: false
    #        roam: true
    #        itemStyle:
    #          normal:
    #            areaColor: '#323c48'
    #            borderColor: '#111'
    #          emphasis: areaColor: '#2a333d'

#          bmap:
#            center: [104.114129, 37.550339]
#            zoom: 5
#            roam: true


          series: [
            {
              name: valueType.name
              type: 'effectScatter'

              coordinateSystem: mapType

              data: options.stationsData
#                  name: child.model.name
#                  key: child.key
#                  type: 'station'
#                  value: [
#                    child.model.longitude
#                    child.model.latitude
#                    child.statistic[type] ? 0
#                  ]
              symbolSize: 30
    #          symbolSize: (val) ->
    #            val[2] / 10
              showEffectOn: 'render'
              rippleEffect: brushType: 'stroke'
              hoverAnimation: true
              label: normal:
#                formatter: (params) ->
#                  "#{params.name}: #{params.value[2]}"
                formatter: '{b}'
                position: 'right'
                show: true
              itemStyle: normal:
                color: '#f4e925'
                shadowBlur: 10
                shadowColor: '#43caff'
              zlevel: 1
            },
            {
              name: valueType.name
              type: 'effectScatter'

              coordinateSystem: mapType

              data: options.equipsData
              
              symbolSize: 16
              showEffectOn: 'render'
              rippleEffect: brushType: 'stroke'
              hoverAnimation: true
              label: normal:
                formatter: '{b}'
                position: 'right'
                show: true
              itemStyle: normal:
                color: '#f4e925'
                shadowBlur: 10
                shadowColor: '#43caff'
              zlevel: 1
            },
          ]

        if mapType is 'bmap'
          option.bmap =
            center: [104.114129, 37.550339]
            zoom: 5
            roam: true
            mapStyle: getMapStyle()
        else
          option.geo =
            map: 'china'
            label: emphasis: show: false
            roam: true

        option
#
#
      initializeBaiduMap = (mychart) =>
    # call baidu map api
        bmap = mychart.getModel().getComponent('bmap').getBMap()

        bmap.addControl new BMap.MapTypeControl()
        bmap.enableScrollWheelZoom true

        bmap.addControl new BMap.NavigationControl
          anchor: BMAP_ANCHOR_TOP_LEFT,
          type: BMAP_NAVIGATION_CONTROL_LARGE,
          enableGeolocation: true

        bmap.addControl new BMap.GeolocationControl()

        bmap.enableAutoResize()
#        bmap.centerAndZoom(new BMap.Point(109.188011,27.736171), 7);

        #地图类型 BMAP_NORMAL_MAP, BMAP_HYBRID_MAP
        if @$routeParams.project is "iiot-kehua"
            #福建
          bmap.setMapType(BMAP_HYBRID_MAP)
          bmap.centerAndZoom(new BMap.Point(118.048689,24.232813), 13);
        else if @$routeParams.project.indexOf("campus") >= 0
          #郑州
          bmap.centerAndZoom(new BMap.Point(113.668643,34.78791), 18);
        else if @$routeParams.project is "iiot-sxbgs"
          bmap.centerAndZoom(new BMap.Point(107.250896,34.361048), 13);
        else
          bmap.centerAndZoom(new BMap.Point(113.202363,22.805745), 13);
        bmap

      getMapStyle = ->
        {
          styleJson: [
            {
              'featureType': 'land',     #调整土地颜色
              'elementType': 'geometry',
              'stylers': {
                'color': '#081734'
              }
            },
            {
              'featureType': 'building',   #调整建筑物颜色
              'elementType': 'geometry',
              'stylers': {
                'color': '#04406F'
              }
            },
            {
              'featureType': 'building',   #调整建筑物标签是否可视
              'elementType': 'labels',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'highway',     #调整高速道路颜色
              'elementType': 'geometry',
              'stylers': {
                'color': '#015B99'
              }
            },
            {
              'featureType': 'highway',    #调整高速名字是否可视
              'elementType': 'labels',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'arterial',   #调整一些干道颜色
              'elementType': 'geometry',
              'stylers': {
                'color':'#003051'
              }
            },
            {
              'featureType': 'arterial',
              'elementType': 'labels',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'green',
              'elementType': 'geometry',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'water',
              'elementType': 'geometry',
              'stylers': {
                'color': '#044161'
              }
            },
            {
              'featureType': 'subway',    #调整地铁颜色
              'elementType': 'geometry.stroke',
              'stylers': {
                'color': '#003051'
              }
            },
            {
              'featureType': 'subway',
              'elementType': 'labels',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'railway',
              'elementType': 'geometry',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'railway',
              'elementType': 'labels',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'all',     #调整所有的标签的边缘颜色
              'elementType': 'labels.text.stroke',
              'stylers': {
                'color': '#313131'
              }
            },
            {
              'featureType': 'all',     #调整所有标签的填充颜色
              'elementType': 'labels.text.fill',
              'stylers': {
                'color': '#FFFFFF'
              }
            },
            {
              'featureType': 'manmade',
              'elementType': 'geometry',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'manmade',
              'elementType': 'labels',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'local',
              'elementType': 'geometry',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'local',
              'elementType': 'labels',
              'stylers': {
                'visibility': 'off'
              }
            },
            {
              'featureType': 'subway',
              'elementType': 'geometry',
              'stylers': {
                'lightness': -65
              }
            },
            {
              'featureType': 'railway',
              'elementType': 'all',
              'stylers': {
                'lightness': -40
              }
            },
            {
              'featureType': 'boundary',
              'elementType': 'geometry',
              'stylers': {
                'color': '#8b8787',
                'weight': '1',
                'lightness': -29
              }
            }
#            ,
#            {
#              'featureType': 'poilabel',  #去除所有应用标签
#              'elementType': 'all',
#              'stylers': {
#                'visibility': 'off'
#              }
#            }
          ]
        }


    getEquipsData:($scope)=>
      @getGeoEquips $scope,(equipDatas)=>
        for equipData in equipDatas
          equipId = equipData.model.station + "." + equipData.model.equipment
          $scope.geoEquipObjs[equipId] =
            id: equipId
            name: equipData.model.name
            key: equipData.key
            type: 'equipment'
            value: [
              equipData.model.longitude
              equipData.model.latitude
              0
            ]
          filter = equipData.getIds()
          filter.station = equipData.model.station
          filter.equipment = equipData.model.equipment
          filter.signal = "_alarms"
          $scope.equipAlarmSubs[equipId]?.dispose()
          $scope.equipAlarmSubs[equipId]  = @commonService.signalLiveSession.subscribeValues filter, (err,d)=>
            if d
              $scope.geoEquipObjs[d.message.station + "." + d.message.equipment].value[2]=d.message.value
              $scope.mapOptions.equipsData = []
              _.mapObject $scope.geoEquipObjs,(val,key)=>
                $scope.mapOptions.equipsData.push val

        $scope.mapOptions.equipsData = []
        _.mapObject $scope.geoEquipObjs,(val,key)=>
          $scope.mapOptions.equipsData.push val

        $scope.$applyAsync()

    getStationsData:($scope)=>
      stationResults = _.filter $scope.project.stations.items,(stationItem)->
        return (stationItem.model.latitude>0 && stationItem.model.longitude>0 )
      for station in stationResults
        @selectStationObjs[station.model.station] =
              id: station.model.station
              name: station.model.name
              key: station.key
              type: 'station'
              value: [
                station.model.longitude
                station.model.latitude
                station.statistic[$scope.signalType] ? 0
              ]
        filter = station.getIds()
        filter.station = station.model.station
        filter.equipment = "_station_management"
        filter.signal = $scope.signalType.type
        @stationAlarmSub[station.model.station]?.dispose()
        @stationAlarmSub[station.model.station]  = @commonService.signalLiveSession.subscribeValues filter, (err,d)=>
          if d
            @selectStationObjs[d.message.station].value[2]=d.message.value
            $scope.mapOptions.stationsData = []
            _.mapObject @selectStationObjs,(val,key)=>
              $scope.mapOptions.stationsData.push val

      $scope.mapOptions.stationsData = []
      _.mapObject @selectStationObjs,(val,key)=>
        $scope.mapOptions.stationsData.push val
      $scope.$applyAsync()
      


    getGeoEquips:(scope,callback)->
      filterStations = _.filter scope.project.stations.items,(item)->
        return (item.model.latitude>0 && item.model.longitude>0 )
      stationCount = 0
      equipsCount = 0
      geoEquips = []
      equipsData = []
      for stationItem in filterStations
        if stationItem.model.station.charAt(0) isnt "_"
          stationItem.loadEquipments null, null, (err, equips)->
            stationCount++
            filterEquipment = _.filter(equips, (item) => item.model.equipment.indexOf("_") == -1)
            equipsData = equipsData.concat(filterEquipment)
            if (stationCount == filterStations.length)
              for equip in equipsData
                equip.loadProperties null, (err, properties)->
                  equipsCount++
                  props = _.filter properties,(propItem)->
                    return (propItem.model.property is "longitude" || propItem.model.property is "latitude") &&  propItem.value > 0
                  if props.length == 2
                    prop = _.find props,(propItem)->
                      return propItem.model.property is "longitude"
                    props[0].equipment.model.longitude = prop.value
                    prop = _.find props,(propItem)->
                      return propItem.model.property is "latitude"
                    props[0].equipment.model.latitude = prop.value
                    geoEquips.push props[0].equipment
                  if equipsCount == equipsData.length
                    callback? geoEquips


    resize: ($scope)->
      $scope.myChart?.resize()
    dispose: ($scope)->
      @datacenterMapSub?.dispose()
      $scope.myChart?.dispose()
      $scope.myChart = null
      _.mapObject @stationAlarmSub,(val,key)->
        val?.dispose()
      _.mapObject $scope.equipAlarmSubs,(val,key)->
        val?.dispose()


  exports =
    DatacenterMapDirective: DatacenterMapDirective