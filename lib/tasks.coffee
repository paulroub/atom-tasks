moment = require 'moment'
_ = require 'underscore'
CSON = require atom.config.resourcePath + "/node_modules/season/lib/cson.js"
TaskGrammar = require './task-grammar'
Grammar = require atom.config.resourcePath +
  "/node_modules/first-mate/lib/grammar.js"

TaskParser = require './parser'

marker = completeMarker = cancelledMarker = ''
# projectRegex = /@project[ ]?\((.*?)\)/
# doneRegex = /@done[ ]?(?:\((.*?)\))?/
# cancelledRegex = /@cancelled[ ]?(?:\((.*?)\))?/

module.exports =

  config:
    dateFormat:
      type: 'string'
      default: "YYYY-MM-DD HH:mm"
    baseMarker:
      type: 'string', default: '☐'
    completeMarker:
      type: 'string', default: '✔'
    cancelledMarker:
      type: 'string', default: '✘'

  activate: (state) ->

    # testing parser stuff
    atom.workspace.observeTextEditors (editor)->
      editor.observeGrammar (grammar)->
        if grammar.name is 'Tasks' and not editor.__tasks
          # editor.__tasks = TaskParser.parse editor
          editor.onDidStopChanging ()->
            # when a change is made, try to
            # reparse the changed lines
            # console.log 'starting parse...'
            # console.time 'parse'
            # editor.__tasks = TaskParser.parse editor
            # console.timeEnd 'parse'



    marker = atom.config.get('tasks.baseMarker')
    completeMarker = atom.config.get('tasks.completeMarker')
    cancelledMarker = atom.config.get('tasks.cancelledMarker')

    atom.config.observe 'tasks.baseMarker', (val)=>
      marker = val; @updateGrammar()
    atom.config.observe 'tasks.completeMarker', (val)=>
      completeMarker = val; @updateGrammar()
    atom.config.observe 'tasks.cancelledMarker', (val)=>
      cancelledMarker = val; @updateGrammar()

    @updateGrammar()

    atom.commands.add 'atom-text-editor',
      "tasks:add": => @newTask()
      "tasks:addAbove": => @newTask(-1)
      "tasks:complete": => @completeTask()
      "tasks:archive": => @tasksArchive()
      "tasks:updateTimestamps": => @tasksUpdateTimestamp()
      "tasks:cancel": => @cancelTask()

  updateGrammar: ->
    clean = (str)->
      for pat in ['\\', '/', '[', ']', '*', '.', '+', '(', ')']
        str = str.replace pat, '\\' + pat
      str

    g = CSON.readFileSync __dirname + '/tasks.cson'
    rep = (prop)->
      str = prop
      str = str.replace '☐', clean marker
      str = str.replace '✔', clean completeMarker
      str = str.replace '✘', clean cancelledMarker
    mat = (ob)->
      res = []
      for pat in ob
        pat.begin = rep(pat.begin) if pat.begin
        pat.end = rep(pat.end) if pat.end
        pat.match = rep(pat.match) if pat.match
        if pat.patterns
          pat.patterns = mat pat.patterns
        res.push pat
      res

    g.patterns = mat g.patterns

    # first, clear existing grammar
    atom.grammars.removeGrammarForScopeName 'source.todo'
    newG = new Grammar atom.grammars, g
    atom.grammars.addGrammar newG

    # Reload all todo grammars to match
    atom.workspace.getTextEditors().map (editorView) ->
      grammar = editorView.getGrammar()
      if grammar.name is 'Tasks'
        # editorView.editor.reloadGrammar()
        editorView.setGrammar newG

  deactivate: ->
    # TODO: Clear markers and __tasks

  serialize: ->

  newTask: (direction = 1)->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    editor.transact ->
      current_pos = editor.getCursorBufferPosition()
      prev_line = editor.lineTextForBufferRow(current_pos.row)
      startLine = current_pos.row

      # Match the indentation of the previous line
      # unless that line is a project definition, in which case,
      # increase the indent one level
      # while prev_line.match(/^(\s*)$/)
      #   prev_line = editor.lineForBufferRow --startLine

      indentLevel = prev_line.match(/^(\s+)/)?[0]
      targTab = Array(atom.config.get('editor.tabLength') + 1).join(' ')
      if prev_line.match /(.*):$/
        indentLevel = null
      indentLevel = if not indentLevel then targTab else ''

      editor.insertNewlineBelow() if direction is 1
      editor.insertNewlineAbove() if direction is -1
      # should have a minimum of one tab in
      editor.insertText indentLevel + atom.config.get('tasks.baseMarker') + ' '

  completeTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()
    console.log selection

    # quick helper
    removeTag = (tagName)->
      # we need to know what part of the
      # line to delete. This will need
      # to use some regex probably and
      # make the proper call to the delete method.

    for range in selection
      for row in range.getRows()
        screenLine = editor.displayBuffer.screenLines[row]
        console.log row, screenLine.text, screenLine

        # see if this is already completed
        token = _.find screenLine.tokens, (i)->
          'tasks.attribute.done' in i.scopes

        if token
          console.log screenLine.bufferColumnForToken token

    # taskRoot = editor.__tasks
    # range = editor.getSelectedBufferRanges()
    # nodes = taskRoot.findNodesByRange range
    #
    # editor.transact ->
    #   _.where nodes, type: 'task'
    #     .map (n)->n.complete()




    # editor.transact ->
    #   {lines, ranges} = mapSelectedItems editor,
    #     (line, lastProject, bufferStart, bufferEnd)->
    #       if not doneRegex.test line
    #         line = line.replace marker, completeMarker
    #         date = moment().format(atom.config.get('tasks.dateFormat'))
    #         line += " @done(#{date})"
    #         line += " @project(#{lastProject.trim()})" if lastProject
    #       else
    #         line = line.replace completeMarker, marker
    #         line = line.replace doneRegex, ''
    #         line = line.replace projectRegex, ''
    #         line = line.trimRight()
    #
    #       editor.setTextInBufferRange [bufferStart,bufferEnd], line
    #   editor.setSelectedBufferRanges ranges
    #
  cancelTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor or not editor.__tasks

    taskRoot = editor.__tasks
    range = editor.getSelectedBufferRanges()
    nodes = taskRoot.findNodesByRange range

    editor.transact ->
      _.where nodes, type: 'task'
        .map (n)->n.cancel()
    # editor = atom.workspace.getActiveTextEditor()
    # return if not editor
    #
    # editor.transact ->
    #   {lines, ranges} = mapSelectedItems editor,
    #     (line, lastProject, bufferStart, bufferEnd)->
    #       if not cancelledRegex.test line
    #         line = line.replace marker, cancelledMarker
    #         date = moment().format(atom.config.get('tasks.dateFormat'))
    #         line += " @cancelled(#{date})"
    #         line += " @project(#{lastProject.trim()})" if lastProject
    #       else
    #         line = line.replace cancelledMarker, marker
    #         line = line.replace cancelledRegex, ''
    #         line = line.replace projectRegex, ''
    #         line = line.trimRight()
    #
    #       editor.setTextInBufferRange [bufferStart,bufferEnd], line
    #   editor.setSelectedBufferRanges ranges

  tasksUpdateTimestamp: ->
    # Update timestamps to match the current setting (only for tags though)
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    editor.transact ->
      nText = editor.getText().replace /@done\(([^\)]+)\)/igm, (matches...)->
        date = moment(matches[1]).format(atom.config.get('tasks.dateFormat'))
        "@done(#{date})"
      editor.setText nText

  tasksArchive: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    editor.transact ->
      ranges = editor.getSelectedBufferRanges()
      # move all completed tasks to the archive section
      text = editor.getText()
      trimmedText = text.trimRight()
      removedText = text.substr trimmedText.length
      text = trimmedText
      raw = text.split('\n') #.filter (line)-> line isnt ''
      completed = []
      hasArchive = false

      original = raw.filter (line)->
        hasArchive = true if line.indexOf('Archive:') > -1
        found = doneRegex.test(line) or cancelledRegex.test(line)
        tabs = Array(atom.config.get('editor.tabLength') + 1).join(' ')
        completed.push line.replace(/^[ \t]+/, tabs) if found
        not found

      newText = original.join('\n') +
        (if not hasArchive then "\n＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿\nArchive:\n" else '') +
        '\n' +
        completed
          .filter (l)-> l isnt ''
          .join('\n') + removedText
      if newText isnt text
        editor.setText newText
        editor.setSelectedBufferRanges ranges
