@App.module "Entities", (Entities, App, Backbone, Marionette, $, _) ->

  ## this is another good candidate for a mutator
  ## with stripping out the parent selector

  class Entities.Command extends Entities.Model
    defaults: ->
      indent: 0
      pause: false
      revert: false

    mutators:
      selector: ->
        _.trim @stripParentSelector()

    indent: (indent) ->
      indent = @parent.get("indent")
      @set "indent", indent + 17

    setParent: (parent) ->
      @parent = parent
      @set "hasParent", true

    hasParent: ->
      !!@get("hasParent")

    isParent: ->
      !!@get("isParent")

    stripParentSelector: ->
      selector = @attributes.selector ? ""

      ## bail if we dont even have a parent
      return selector if not @hasParent()

      parent = @parent.attributes.selector ? ""

      ## replace only the first occurance of the parent selector
      selector.replace parent, ""

    setResponse: ->
      @set "status", @xhr.status
      @set "response", @xhr.responseText

    getDom: ->
      @dom

    getEl: ->
      @el

  class Entities.CommandsCollection extends Entities.Collection
    model: Entities.Command

    parentExistsFor: (instanceId) ->
      ## this returns us the last (parent)
      found = @filter (command) ->
        command.isParent() and command.get("instanceId") is instanceId

      _(found).last()

    lastCommandIsNotRelatedTo: (command) ->
      ## does the last command's instanceId not match ours?
      @last().get("instanceId") isnt command.get("instanceId")

    insertParent: (parent) ->
      clone = parent.clone()

      _.each ["el", "dom", "parent"], (prop) ->
        clone[prop] = parent[prop]

      @add clone

    getCommandByType: (attrs) ->
      switch attrs.type
        when "dom" then @addDom attrs
        when "xhr" then @addXhr attrs

    addDom: (attrs) ->
      {el, dom} = attrs

      attrs = _(attrs).omit "el", "dom"

      attrs.highlight = true

      ## instantiate the new model
      command = new Entities.Command attrs
      command.dom = dom
      command.el = el

      ## if we're chained to an existing instanceId
      ## that means we have a parent

      if parent = @parentExistsFor(attrs.instanceId)
        command.setParent parent
        command.indent()
        ## we want to reinsert the parent if this current command
        ## is not related to our last.
        ## that means something has been inserted in between our command
        ## instance group and we need to insert the parent so this command
        ## looks visually linked to its parent
        if @lastCommandIsNotRelatedTo(command)
          # debugger
          @insertParent(parent)

      return command

    addXhr: (attrs) ->
      {xhr} = attrs

      attrs = _(attrs).omit "xhr"

      ## does an existing xhr command already exist?
      if command = @parentExistsFor(attrs.instanceId)
        ## if so update its response body
        command.setResponse()
        command.doNotAdd = true

      else
        ## instantiate the new model
        command = new Entities.Command attrs
        command.xhr = xhr

      return command

    add: (attrs, type, runnable) ->
      try
        ## bail if we're attempting to add a real model here
        ## instead of an object
        return super(attrs) if attrs instanceof Entities.Command

      return if _.isEmpty attrs

      _.extend attrs,
        type: type
        testId: runnable.cid

      command = @getCommandByType(attrs)

      console.warn "command model is: ", command

      ## need to refactor this
      return command if command.doNotAdd

      super command

  App.reqres.setHandler "command:entities", ->
    new Entities.CommandsCollection