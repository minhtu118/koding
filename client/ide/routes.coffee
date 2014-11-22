do ->

  loadWorkspace = (machineLabel, workspaceSlug, username, privateMessageId) ->
    username or= KD.nick()
    workspace  = ws  for ws in KD.userWorkspaces when ws.slug is workspaceSlug
    machine    = getMachine machineLabel, username

    if workspace
      loadIDE { machine, workspace, username, privateMessageId }

    else
      if workspaceSlug is 'my-workspace'
        workspace =
          isDummy      : yes
          isDefault    : yes
          slug         : 'my-workspace'
          machineLabel : machine?.slug or machine?.label

        loadIDE { machine, workspace, username, privateMessageId }

      else
        routeToLatestWorkspace()


  selectWorkspaceOnSidebar = (data) ->
    mainView = KD.getSingleton 'mainView'
    mainView.activitySidebar.selectWorkspace data


  getMachine = (label, username) ->
    machine = null

    for m in KD.userMachines
      hasSameLabel = (m.label is label) or (m.slug is label)
      hasSameUser  = m.data.credential is username

      if hasSameLabel and hasSameUser
        machine = m

    return machine


  loadIDE = (data) ->

    { machine, workspace, username, privateMessageId } = data

    appManager = KD.getSingleton 'appManager'
    ideApps    = appManager.appControllers.IDE
    machineUId = machine?.uid
    callback   = ->
      appManager.open 'IDE', { forceNew: yes }, (app) ->
        app.mountedMachineUId   = machineUId
        app.workspaceData       = workspace

        if username
          app.isCollaborative   = yes
          app.amIHost           = no
          app.collaborationHost = username
          app.privateMessageId  = privateMessageId
        else
          app.amIHost           = yes

        appManager.tell 'IDE', 'mountMachineByMachineUId', machineUId
        selectWorkspaceOnSidebar data

    return callback()  unless ideApps?.instances

    for instance in ideApps.instances
      isSameMachine   = instance.mountedMachineUId is machineUId
      isSameWorkspace = instance.workspaceData is workspace

      if isSameMachine
        if isSameWorkspace then ideInstance = instance
        else if workspace.slug is 'my-workspace'
          if instance.workspaceData?.isDefault
            ideInstance = instance

    if ideInstance
      appManager.showInstance ideInstance
      selectWorkspaceOnSidebar data
    else
      callback()


  putVMInWorkspace = (machine)->
    localStorage    = KD.getSingleton("localStorageController").storage "IDE"
    latestWorkspace = localStorage.getValue 'LatestWorkspace'

    machineLabel    = machine?.slug or machine?.label or ''
    workspaceSlug   = 'my-workspace'

    if latestWorkspace
      for ws in KD.userWorkspaces when ws.slug is latestWorkspace.workspaceSlug
        {machineLabel, workspaceSlug} = latestWorkspace

    KD.getSingleton('router').handleRoute "/IDE/#{machineLabel}/#{workspaceSlug}"


  routeToLatestWorkspace = ->

    machine = KD.userMachines.first
    return putVMInWorkspace machine  if machine

    KD.singletons.computeController.fetchMachines (err, machines)->

      if err or not machines.length
        KD.getSingleton('router').handleRoute "/IDE/koding-vm-0/my-workspace"
        return

      putVMInWorkspace machines.first


  KD.registerRoutes 'IDE',

    '/:name?/IDE': -> routeToLatestWorkspace()

    '/:name?/IDE/:machineLabel': -> routeToLatestWorkspace()

    '/:name?/IDE/:machineLabel/:workspaceSlug': (data) ->

      { machineLabel, workspaceSlug } = data.params

      loadWorkspace machineLabel, workspaceSlug

    '/:name?/IDE/:machineLabel/:workspaceSlug/:username/:privateMessageId': (data) ->

      { machineLabel, workspaceSlug, username, privateMessageId } = data.params

      loadWorkspace machineLabel, workspaceSlug, username, privateMessageId