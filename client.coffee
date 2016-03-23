Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
App = require 'app'
Event = require 'event'
Icon = require 'icon'
Obs = require 'obs'
Page = require 'page'
Form = require 'form'
Time = require 'time'
Ui = require 'ui'
{tr} = require 'i18n'

Config = require 'config'
Draw = require 'draw'
View = require 'view'

exports.render = !->
	pageName = Page.state.get(0)
	log "pageName", pageName
	return Draw.render() if pageName is 'draw'
	return renderScores() if pageName is 'scores'
	return View.render() if pageName # anything else

	renderOverview()

renderOverview = !->
	Comments.enable
		messages: # no longer generated
			new: (c) -> tr("%1 added a new drawing", c.user)

	Obs.observe !->
		if Db.shared.get 'outOfWords'
			Ui.item
				icon:'info'
				color: '#999'
				content: tr("No more words left to sketch")
				sub: tr("We know of your hardship and will add new words shortly.")
				style: color: '#999'
			return
		t = (Db.personal.get('wait')||1458648797)+Config.cooldown()
		if t <= Date.now()*0.001
			Ui.item
				icon: 'add'
				content: tr("Start sketching")
				onTap: !->
					Page.nav 'draw'
		else
			Ui.item
				icon:'chronometer'
				color: '#999'
				content: !->
					Dom.text tr("Wait ")
					Time.deltaText t, 'duration'
				sub: !->
					wg = Db.personal.get('waitGuessed')
					if wg>1
						Dom.text tr("Or until %1 more people guessed your previous sketch", wg)
					else if wg is 1
						Dom.text tr("Or until %1 more person guessed your previous sketch", wg)
					else
						Dom.text tr("Or until more people guessed your previous sketch")
				style: color: '#999'

	yourId = App.memberId()
	afterIcon = (drawing, showPoints=true) !->
		drawingId = drawing.key()
		if Event.getUnread ['/'+drawingId+"?comments"]
			Event.renderBubble ['/'+drawingId+"?comments"]
		else
			Dom.div !->
				return unless drawing.getKeys? # might not be available yet. core update
				nrOfMsg = drawing.get('comments', 'max') - drawing.getKeys('members').length
				return unless nrOfMsg > 0
				Dom.style Box: 'middle', marginRight: '5px'
				Icon.render
					data: 'chat3'
					color: '#ddd'
					size: 16
					style: padding: '3px'
				Dom.div !->
					Dom.style
						color: '#ddd'
						fontSize: 14
					Dom.text nrOfMsg
		if showPoints
			points = Db.shared.get('scores', yourId, drawingId)||0
			View.renderPoints(points, 40)

	Db.shared.iterate 'drawings', (drawing) !->
		memberId = drawing.get('memberId')
		state = drawing.get 'members', yourId
		item =
			avatar: App.memberAvatar(memberId)
			onTap: !-> Page.nav {0:drawing.key()}
		isNew = Event.isNew(drawing.get('time'))
		if isNew
			item.style = color: '#5b0'

		if memberId is yourId # own sketch
			mem = drawing.get('members')
			if mem
				(delete mem[k] if v is -1) for k,v of mem # skip members with a time of -1
			what = Db.personal.get('words', drawing.key())||false
			if what
				r = /^([a-z]*\s)?(.*)$/i.exec what
				prefix = if r[1] then r[1] else ""
				what = r[2]
				item.content = !->
					Dom.userText tr("**You sketched %1**", prefix)
					Dom.span !->
						color = if isNew then '#5b0' else '#0077CF'
						Dom.style color: color, fontWeight: 'bold'
						Dom.text what
			else
				item.content = tr("Your sketch")
			if mem and Object.keys(mem).length
				item.sub = !->
					Dom.text tr("Guessed by ")
					Dom.text (a = (App.memberName(+k) for k, v of mem)).join(" · ")
				item.afterIcon = !-> afterIcon drawing
			else
				item.sub = !->
					Dom.text tr("Guessed by no one yet")
		else if state? and state isnt -1 # you've guessed it
			what = Db.personal.get('words', drawing.key())||false
			if what
				r = /^([a-z]*\s)?(.*)$/i.exec what
				prefix = if r[1] then r[1] else ""
				what = r[2]

				item.content = !->
					Dom.userText tr("%1 sketched %2", App.memberName(memberId), prefix)
					Dom.span !->
						color = if isNew then '#5b0' else '#0077CF'
						Dom.style color: color, fontWeight: 'bold'
						Dom.text what
			else
				item.content = tr("Sketching by %1", App.memberName(memberId))
			if state >= 0
				item.sub = tr("Guessed by you in %1 second|s", state)
			else
				item.sub = tr("You failed to guess")
			item.afterIcon = !-> afterIcon drawing
		else # no state, so not guessed yet
			item.content = tr("Guess sketch by %1", App.memberName(memberId))
			item.sub= !->
				Dom.text "Sketched "
				Time.deltaText(drawing.get('time'))
			item.afterIcon = !-> afterIcon drawing, false
				# Event.renderBubble ['/'+drawing.key()+"?comments"]

		Ui.item item

	, (drawing) ->
		-drawing.peek('time')|0
	Page.setFooter
		label: 'See scores'
		action: !-> Page.nav {0:'scores'}

renderScores = !->
	App.members.iterate (member) !->
		scores = Db.shared.get('scores', member.key())
		Ui.item
			avatar: member.get('avatar')
			content: member.get('name')
			sub: tr("Guessed %1 sketch|es", Object.keys(scores||{}).length)
			afterIcon: !->
				s = 0
				s += v for k, v of scores
				View.renderPoints(s, 40)
			onTap: !->
				App.showMemberInfo member.key()
	, (member) ->
		s = 0
		s += v for k, v of Db.shared.get('scores', member.key())
		-s

exports.renderSettings = !->
	Dom.h2 tr("Language")

	iniValue = 'en1'
	if Db.shared then iniValue = Db.shared.get('wordList')

	Form.segmented
		name: 'wordList'
		value: iniValue
		segments: ['en1', tr("English"), 'nl1', tr("Dutch")]
		onChange: (v) !->
			log "on change", v