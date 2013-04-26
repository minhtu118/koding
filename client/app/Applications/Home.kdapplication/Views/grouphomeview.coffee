class GroupHomeView extends KDView

  constructor:(options = {}, data)->

    options.domId    = "home-group-header"
    options.cssClass = "screenshots"

    super options, data

  viewAppended:->
    entryPoint       = @getOption 'entryPoint'
    groupsController = @getSingleton "groupsController"

    KD.remote.cacheable entryPoint, (err, models)=>
      if err then callback err
      else if models?
        [group] = models
        @setData group
        @addSubView @body = new KDScrollView
          domId     : 'home-group-body'
          tagName   : 'section'
          pistachio : """<div class='group-desc'>{{ #(body)}}</div>"""
        , group
        @addSubView @homeLoginBar = new HomeLoginBar
          domId : "group-home-links"
        @addSubView @readmeView = new GroupReadmeView
          domId : "home-group-readme"
        , group
        @readmeView.on "readmeReady", => @emit "ready"
