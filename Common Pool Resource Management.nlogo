extensions [table cf palette ] ;color-generator ]

;extensions [table cf goo gradient ] ;color-generator ]


breed [ cows cow ]  ;; creation controlled by farmers
breed [ farmers farmer ] ;; created and controlled by clients
breed [ fences fence]

globals [
  ;; make some tables for saving this stuff for later.
  farmer-actions

  average-cows-per-player ;; the number of cows per average per player that the field can sustain

  max-grass ;; the max amount of grass on a patch
  cows-eat ;; the amount cows eat per turn
  cows-max-energy ;; the amount that cows can store
  cows-metabolize-week ;; the amount that cows metabolize per day
  grass-regrow ;; the amount that grass grows back
  fence-fix-points
  shepherd-bonus ; the extra amount of food cows will try to eat if they are being shepherded

  cow-price

  ;; this might need balancing too
  seed-cost
  fence-fixing-cost

  edge-patches ;; all patches along the edge. might as well just put them in one patchset to begin with
  grass-patches

  common-pool-bank ;; this is money that people have pooled together

  seen-this-week

  ;; some plotting lists
  actual-grass-amounts
  total-milk-production
  actual-fence-states
  money-in-the-bank
  count-cows-history
  ;; maybe log:
  ;; standard deviation of milk production of farmers

  ;; for setting up quickly
  do-options
  say-options

  ;; logs
  who-herded
  who-monitored
  who-repaired
  who-sowed
  who-said-herded
  who-said-monitored
  who-said-repaired
  who-said-sowed
]

cows-own
[
  owner             ;; the user-id of the farmer who owns the goat
  energy            ;; amount the cow has eaten this round
]

farmers-own
[
  user-id            ;; unique user-id, input by the client when they log in,
                     ;; to identify each student turtle
  milk-production-list       ;; list of each days' revenue collection
  donations-list

  say-will-do
  will-do  ;; will they defect today
  money

  is-bot? ;; is this a bot?

  money-to-bank ;;
]

fences-own [
 durability
]

patches-own[
  grass
  water
]

to run-a-week
;  hubnet-broadcast-clear-output

  ;; only run the week if everybody has decided what to do
  let undecided-farmers farmers with [will-do = undecided or say-will-do = undecided]
  if any? undecided-farmers [show (word [user-id] of undecided-farmers " still undecided.") stop]

  hubnet-broadcast-message (word "Week " ticks " starting!")
  ;; clear who was seen this week
  set seen-this-week (turtle-set)


  ;; we can figure out how to do the visualization later. But here are the options:
  ;; I wonder if we should actually let people do other things too. They could decide to inspect fences without telling anyone
  ;; so that they can catch defectors.
  ask farmers [do-weekly-action]

  ;; all cows graze. We do this to make sure everybody's cows get an equal chance at eating,
  ;; and to smoothe out movement animation
  repeat 7 [ask cows [graze metabolize-and-maybe-die]]

  ;; calculate how much milk they get (we need a better function for this, I think)
  ask farmers [
    sell-milk
    update-client-info
    ]
  ;; fences deteriorate
  ask fences [
   deteriorate
   ]

  ;; grass regrows
  ask grass-patches [
    grow-grass grass-regrow
    recolor-grass ;; we may not want to do this unless people "survey" the grass
  ]

  tick
 show-who-was-seen-this-week
  ask farmers [
    log-player-action "say" say-will-do
    log-player-action "do" will-do
  ]
  update-fence-labels
  log-weekly

  reset-weekly-vars
  update-plots
  hubnet-send-message "Status" "This is the weekly town hall meeting. Coordinate with the rest of the village, and decide what you will do next week."

end

to deteriorate
  set durability round (durability - random 25)
  if durability < 0 [set durability 0]
end

to reset-weekly-vars
  ask farmers [set will-do undecided set say-will-do undecided]
  hubnet-broadcast "Status" "Choose what to say and do this week."
  set seen-this-week (turtle-set)
end


to log-weekly
set actual-grass-amounts lput sum [grass] of grass-patches actual-grass-amounts
set  total-milk-production lput sum [last milk-production-list] of farmers total-milk-production
set actual-fence-states lput mean [durability] of fences actual-fence-states
set  money-in-the-bank lput common-pool-bank money-in-the-bank
set count-cows-history lput count cows count-cows-history
set who-monitored lput farmers with [will-do = "Do: Monitor Peers"] who-monitored
set who-herded lput farmers with [will-do = "Do: Herd Cows"] who-herded
set who-repaired lput farmers with [will-do = "Do: Repair Fences"] who-repaired
set who-sowed lput farmers with [will-do = "Do: Sow Grass"] who-sowed
set who-said-monitored lput farmers with [will-do = "Say: Monitor Peers"] who-said-monitored
set who-said-herded lput farmers with [will-do = "Say: Herd Cows"] who-said-herded
set who-said-repaired lput farmers with [will-do = "Say: Repair Fences"] who-said-repaired
set who-said-sowed lput farmers with [will-do = "Say: Sow Grass"] who-said-sowed

end


to do-weekly-action
  let people-i-met (turtle-set)
  (
    cf:match will-do
    cf:= "Do: Repair Fences ($500)"
    [
      fix-fences
      set people-i-met union people-i-met meet-fence-fixers-with-probability 10
      set people-i-met union people-i-met meet-cow-herders-with-probability 5
      set people-i-met union people-i-met meet-grass-surveyors-with-probability 20
      set people-i-met union people-i-met meet-grass-sowers-with-probability 5
      set people-i-met union people-i-met meet-fence-inspectors-with-probability 100
    ]
    cf:= "Do: Monitor Peers"
    [
      set people-i-met union people-i-met meet-fence-fixers-with-probability 50
      set people-i-met union people-i-met meet-cow-herders-with-probability 50
      set people-i-met union people-i-met meet-grass-surveyors-with-probability 50
      set people-i-met union people-i-met meet-grass-sowers-with-probability 50
      set people-i-met union people-i-met meet-fence-inspectors-with-probability 50
    ]
    cf:= "Do: Sow Grass ($500)"
    [
      sow-grass
      set people-i-met union people-i-met meet-fence-fixers-with-probability  10
      set people-i-met union people-i-met meet-cow-herders-with-probability 25
      set people-i-met union people-i-met meet-grass-surveyors-with-probability 50
      set people-i-met union people-i-met meet-grass-sowers-with-probability 25
      set people-i-met union people-i-met meet-fence-inspectors-with-probability 10
    ]
    cf:else []
    )
;  show (word "people I met " count people-i-met)
  ;; remove self from people I met
  set people-i-met other people-i-met
  set seen-this-week (turtle-set seen-this-week people-i-met)
  show-who-i-met people-i-met
end

to show-who-i-met [people-i-met]
  let weekly-digest (word "This week, while " present-tense-action " you see ")
  let sorted-people sort-on [will-do] people-i-met
  ifelse count people-i-met = 0[
    set weekly-digest (word weekly-digest "nobody")
  ]
  [
  foreach remove-duplicates [will-do] of (turtle-set sorted-people) [
    set weekly-digest (word weekly-digest people-names [user-id] of people-i-met with [will-do = ?])
    set weekly-digest (word weekly-digest ", who were " [present-tense-action] of one-of people-i-met with [will-do = ?] ";")
  ]
  ]
 hubnet-send-message user-id weekly-digest
end


to-report people-names [alist] ;; AH: this isn't working
  report ifelse-value (length alist > 1) [(word first alist ", " people-names butfirst alist)] [(first alist )]
end

to-report  present-tense-action
;  show will-do
  report (cf:match-value will-do
    cf:= "Do: Herd Cows" ["herding cows"]
    cf:= "Do: Repair Fences ($500)" ["repairing fences"]
    cf:= "Do: Inspect Fences" ["inspecting fences"]
    cf:= "Do: Sow Grass ($500)" ["sowing grass"]
    cf:= "Do: Survey Grass" ["surveying grass"]
    cf:= "Do: Monitor Peers" ["monitoring peers"]
    )
end



to sow-grass ;; sowing grass let's grass
             ;; NB: THIS MIGHT NEED TWEAKING
  if length hubnet-clients-list > 0 [
    ask grass-patches [grow-grass grass-regrow / length hubnet-clients-list]
  ]

end

to metabolize-and-maybe-die
  set energy energy - (cows-metabolize-week / 15) ;; 15 is a magic number. it just sort of seems to work
  if energy < 0 [
    hubnet-send-message [user-id] of owner "One of your cows starved to death!"
    die
  ]
end

to sell-milk
  ;; this is a bit silly but only take energy from cows that are alive. we kill off the ones that are about to die
  ;; later.
  let total-production [energy] of my-cows with [energy > 0]
  let profit round sum total-production
  set money money + profit
  set milk-production-list lput profit milk-production-list
end


to fix-fences
  let fix-points fence-fix-points
  while [any? fences with [label < 100] and fix-points > 0] [
    let most-broken-fence min-one-of fences [label]
    move-to most-broken-fence
    let repair-amount min (list fix-points (100 - [durability] of most-broken-fence))
    ask most-broken-fence [set durability durability + repair-amount set label durability]
    set fix-points fix-points - repair-amount
  ]
  set money money - fence-fixing-cost
end

to update-fence-labels
  ask fences [set label durability]
end

to-report meet-fence-fixers-with-probability [%-prob]
  report fence-fixers with [random 100 < %-prob]
end
to-report meet-grass-sowers-with-probability [%-prob]
  report grass-sowers with [random 100 < %-prob]
end
to-report meet-cow-herders-with-probability [%-prob]
  report cow-herders with [random 100 < %-prob]
end
to-report meet-grass-surveyors-with-probability [%-prob]
  report grass-surveyors with [random 100 < %-prob]
end
to-report meet-fence-inspectors-with-probability [%-prob]
  report fence-inspectors with [random 100 < %-prob]
end


to graze
  eat
  cow-move
end

to cow-move
  ;; if they are on an edge patch, they die
  if member? patch-here edge-patches [
    set pcolor red
    hubnet-send-message [user-id] of owner (word "One of your cows disappeared. A fence must be broken somewhere.")
    die
    ]
  ;; cows wander around randomly
  rt random 30
  lt random 30
  ;; if there's a fence in front of them, turn around
  ifelse ([ any? fences-here with [durability > 0]] of patch-ahead 1) [rt 90]  [fd 1]
end

to eat
  ;; let cows eat 20% more if their owner shepherds
  let my-max-eat ifelse-value [shepherding-this-week?] of owner [cows-eat * (1 + shepherd-bonus)] [cows-eat]
  let stomach-space-left cows-max-energy - energy
  let eaten-amount min (list stomach-space-left grass cows-eat)
  set energy energy  + eaten-amount
  set grass grass - eaten-amount
end

to setup
  ca
  hubnet-reset
  setup-clean
end


to setup-clean
  clear-output
  setup-globals
  setup-world
  ask farmers [
    ask my-cows [die]
    set milk-production-list (list)
    set money cow-price * 2 + 250
    update-client-info
    hubnet-broadcast-clear-output
    hubnet-send user-id "Status" "Welcome to the weekly town hall meeting. Coordinate with your village, and decide what to do next week."
  ]


  clear-all-plots
  setup-plots
  reset-ticks

end


to go
  hubnet-broadcast "Status" "Choose what to do this week!"
end



to setup-world
  set edge-patches patches with [pxcor = min-pxcor or pxcor = max-pxcor or pycor = min-pycor or pycor = max-pycor]
  set grass-patches patches with [not member? self edge-patches]
  ask grass-patches [
    set grass random-float max-grass
    recolor-grass]
  ask fences [die]
  ask edge-patches [
    sprout-fences 1 [set shape "fence" set heading 0 set color brown set durability 50 + random 50 set label durability]
    set grass 0
    set pcolor green
    ]
end

to setup-globals
  set farmer-actions (list)
  set actual-grass-amounts (list)
  set  total-milk-production (list)
  set actual-fence-states (list)
  set  money-in-the-bank  (list)
  set count-cows-history (list)

  set who-herded (list)
  set   who-monitored (list)
  set   who-repaired (list)
  set   who-sowed (list)
  set   who-said-herded (list)
  set   who-said-monitored (list)
  set   who-said-repaired (list)
  set   who-said-sowed   (list)

  set seen-this-week (turtle-set)
  set common-pool-bank 500
  scale-vars-for-n-players
  set fence-fixing-cost 500
  set seed-cost 500
  set cow-price 1500
  set do-options (list "Do: Herd Cows" "Do: Repair Fences ($500)" "Do: Sow Grass ($500)" "Do: Monitor Peers" )
  set say-options (list "Say: Herd Cows" "Say: Repair Fences ($500)" "Say: Sow Grass ($500)" "Say: Monitor Peers" )

end


to scale-vars-for-n-players
  let no-of-farmers count farmers
    ;; extra food that cows will try to eat if they are being shepherded
  set shepherd-bonus .2
  ;; 961 patches with grass growing on it.
  ;; we need to balance how fast grass grows back, how quickly fences deteriorate, and how how grass
  ;; can be on each patch so that the world automatically can support N people. (N = no-of-farmers.)
  ;; Let's assume that people start with three cows, and we want the game to go on for "a while". Let's say that
  ;; at its base level, the world can support 6 cows per player.
  ;; let's just say that a cow needs 7 energy to sustain itself for a week.
  ;; in that case, the entire system (without extra work towards it) should produce
  ;; 7 * 6 * n-of-farmers, or 42 per player, per week. That's an odd number for this just because it would mean that
  ;; a lot of the patches would not produce anything or they would produce a fraction of an energy's worth of food
  ;; so maybe we should say 70 per week? that will make the numbers more on an order that makes sense.
  set cows-metabolize-week 70
  ;; cows metabolize 10 per day, and they should be able to eat as much as they metabolize plus... 50? let's try that
  set cows-eat cows-metabolize-week * 1.5 / 7  ;; the amount cows eat per turn
  ;; let's say that cows can eat at most 33% of the grass on a patch per day, so that means max-grass is 45
  set max-grass cows-eat * 3
  ;; let's also say that a cow can store enough energy to not eat at all for one week. That means they can store a total of
  ;; 7 * 10  = 70.
  set cows-max-energy 2 * cows-metabolize-week ;; the amount that cows can store
  ;; if the whole system should have a base-carrying capacity of 700 * 6 = 4200
  set average-cows-per-player 8
  ;; interestingly, it can only sustain around 3.5 per player with this.  I'll try to increase it
  set grass-regrow ( no-of-farmers * average-cows-per-player * cows-metabolize-week) / (2 * count patches with [not any? fences-here]) ;; 2 is a magic number here. it just works ;; the amount that grass grows back
  ;; ah: grass regrow is still too high. going to take it down a bit
  set grass-regrow grass-regrow / 4

  ;; there are 128 fences, each with 100 points of durability
  ;; we should scale how many points they get to fix them with, rather than the durability decline. in the case of the former
  ;; it will just get to the point where fences need fixing sooner (if I am running this correctly in my head)
  ;; So: 128 fences declining by up to 25 points each turn, with a mean of 12.5
  ;; 128 * 12.5 = 1600.
  ;; we want one fifth of players fixing fences all the time, so
  ;; if no one has logged in, don't do this or we get division by zero
  if count farmers  > 0 [
    set fence-fix-points (1600 * 5) / count farmers
  ]

end


to listen-to-clients
  every .1 [
    while [hubnet-message-waiting?]
    [
      hubnet-fetch-message
      (cf:cond
        cf:case [ hubnet-enter-message? ] [ add-farmer hubnet-message-source false ]
      cf:case [hubnet-exit-message?] [];kill-farmer hubnet-message-source]
      cf:else [ do-command hubnet-message-source hubnet-message-tag])
    ]
  ]
end

to add-farmer [message-source bot?]

  create-farmers 1 [
    set is-bot? bot?
    move-to one-of grass-patches
    set shape "person"
    set user-id message-source
    set money cow-price * 2 + 250 ; give everybody enough money to buy two cows, plus change.
    set color one-of base-colors
    set milk-production-list []
    reset-farmer
    set money-to-bank 20 ;; this is what it inits to in the client view
    if not is-bot?[
      update-client-info
      hubnet-send message-source "Status" "Welcome to the weekly town hall meeting. Coordinate with your village, and decide what to do next week."
;      hubnet-send- message-source one-of farmers with [user-id = message-source]
    ]
    display

  ]

  wait .05
;  goo:set-chooser-items "farmer-list" sort [user-id] of farmers;sort hubnet-clients-list
  wait .05
;  set farmer-list item 0 sort [user-id] of farmers;hubnet-clients-list

  scale-vars-for-n-players

end

to kill-farmer [message-source]
  ask farmers with [user-id = message-source ] [die]
  scale-vars-for-n-players
end

to do-command [source tag]
  ask farmers with [user-id = source] [
    let update-client-display true
    ;; ifelse/case here for different kinds
    (cf:cond
      cf:case [member? "Say:" tag] [
        hubnet-send source "Status" (word "You " tag)
        set say-will-do tag
        print-who-says-what
        ]
    cf:case [member? "Do:" tag] [
      ;; only set this if they can afford it. Otherwise tell them they can't afford it.
      ifelse can-afford-action? tag
        [
          hubnet-send source "Status" (word "You will " tag )
          set will-do tag print-who-says-what
        ]
        [
          hubnet-send source "Status" (word "You can't afford " tag)
        ]
    ]
    cf:case [tag = "Buy Cow ($1500)"][
      buy-cow
    ]
    cf:case [tag = "money-to-shared-bank"]
    [
      ask farmers with [user-id = source] [set money-to-bank hubnet-message]
    ]
    cf:case [tag = "Donate"][
      ask farmers with [user-id = source] [
      donate-to-common-$  money-to-bank
      ]
    ]
    cf:else [ set update-client-display false ]
    )
    ;; tell them if they still need to make a decision
    if will-do = undecided and say-will-do = undecided [
    hubnet-send source "Status" "Decide what to say and do this week."
    ]
    if will-do != undecided and say-will-do = undecided [
    hubnet-send source "Status" "Decide on what you say you will do."
    ]
    if will-do = undecided and say-will-do != undecided [
    hubnet-send source "Status" "Decide on what you will actually do."
    ]
    if will-do != undecided and say-will-do != undecided [
    hubnet-send source "Status" "You are ready for this week."
    ]

  ]
end

to buy-cow
  ifelse money >= 1500
  [
    set money money - 1500
    make-cow
    ]
  [
    hubnet-send user-id "Status" "You can't afford a cow yet."
  ]

end

to-report can-afford-action? [an-action-string]
  report not member? "$" an-action-string or money > 500
end

to show-who-says [astring]
  let the-users sort [user-id] of farmers with [say-will-do = astring]
    output-print (word astring " (" length the-users ")")
    output-print ifelse-value (length the-users > 0) [people-names the-users] ["Nobody"]
end

to print-who-says-what
  clear-output
  output-print "What people say this week"
  let things-people-say sort remove-duplicates [say-will-do] of farmers
  foreach things-people-say [
    show-who-says ?
  ]
end

to reset-farmer
  set say-will-do undecided
  set will-do undecided
end

to grow-grass [grow-amount]
  set grass min (list max-grass (grass + grow-amount))
end

to recolor-grass
  set pcolor palette:scale-gradient [[90 60 0] [0 255 0]] grass  0 max-grass
end

to-report my-cows  ;; farmer procedure, returns agentset of their cows
    report cows with [owner = myself]
end

;; farmer reporter. will they shepherd this week
to-report shepherding-this-week?
  report will-do = "Do: Shepherd my Cows"
end

;; AH: OK, we'll just do one large table full of 'action tables'. An
;; action table contains the hubnet-id, the type of action, the week it happened, and a value
;; AH: thinking about it, i'm not even sure this is worth it. fuck it, we'll do it live. with lists.
to log-player-action [action value]
  set farmer-actions lput (list user-id ticks action value) farmer-actions
end

;; plotting procedures
to show-in-plot [plot-no]
  set-current-plot (word "Plot " plot-no)
  clear-plot
  let the-list get-plot-list plot-value
  if length the-list = 0 or sum the-list = 0 [stop]
  set-plot-x-range 0 length the-list
  set-plot-y-range 0 precision ((max the-list) * 1.1) 0
  create-temporary-plot-pen plot-value
  plotxy 0 0
  foreach the-list [
    plot ?
  ]
  update-plots
end



to-report get-plot-list [plot-list-description]
  report (
    cf:match-value plot-list-description
    cf:= "Total Milk Production" [total-milk-production]
    cf:= "Money in Bank" [money-in-the-bank]
    cf:= "Grass Amount" [actual-grass-amounts]
    cf:= "State of Fences" [actual-fence-states]
    cf:= "Number of Cows" [count-cows-history]
    )
end

to fine-them [a-user-id]
  let the-farmer one-of farmers with [user-id = a-user-id]
  ask the-farmer [
    ifelse money >= $-amount [
      set money money - $-amount
      set common-pool-bank common-pool-bank + $-amount
      hubnet-send user-id "$" money
    ]
    [
      show (word user-id " does not have $ " $-amount "!")
    ]
  ]
end

to donate-to-common-$ [$-to-donate]
  show "trying to donate"
  ifelse money >= $-to-donate [
    set money money - $-to-donate
    set common-pool-bank common-pool-bank + $-to-donate
    hubnet-send user-id "$" money
  ]
  [
    hubnet-send-message user-id (word "You don't have $" $-to-donate " in your bank!")
  ]
end

to give-$-to-farmer [a-user-id]
  ifelse common-pool-bank >= $-amount [
    ask farmers with [user-id = a-user-id] [
      set money money + $-amount
      set common-pool-bank common-pool-bank - $-amount
      hubnet-send user-id "$" money
    ]
  ]
  [
    show "The common pool bank doesn't have that much money!"
  ]
end


to update-client-info
   hubnet-send user-id "$" money
   hubnet-send user-id "# of Cows" (count my-cows)
   hubnet-send-override user-id my-cows "color" [red]
   hubnet-send-override user-id my-cows "size" [2]
end

to make-cow
;  show self
  hatch-cows 1 [
;    show myself
     set owner myself set shape "cow" set color brown set energy 10 move-to one-of grass-patches ;st ;display
     ]
  update-client-info
end

to-report gini-points
  let points []
  let sorted-farmers sort-on [wealth] farmers
  let total-wealth (sum [wealth] of farmers)
  let sum-so-far 0
  let %-per-farmer 100 / count farmers
  let counter 0
  foreach sorted-farmers [
    set counter counter + 1
    set sum-so-far sum-so-far + ([money + 1500 * count my-cows] of ?)
    let %-of-total-wealth sum-so-far / total-wealth
    let point (list (counter * %-per-farmer / 100) %-of-total-wealth)
    set points lput point points
  ]
  report points
end

to show-gini
  set-current-plot "gini-coefficient"
  clear-plot
  create-temporary-plot-pen "gini"
  plotxy 0 0
  foreach gini-points [
    plotxy first ? last ?
  ]
  create-temporary-plot-pen "baseline"
  plotxy 0 0
  plotxy 100 100
end

to print-who-did-what
  clear-output
  foreach all-weeks-in farmer-actions [
    let the-week ?
    output-print (word "During week " the-week )
    foreach things-people-did-in farmer-actions [
      let the-action ?
      let farmers-who-did-that-this-week filter [item 1 ? = the-week and item 3 ? = the-action] farmer-actions
      output-print (word the-action " (" length farmers-who-did-that-this-week ")")

      ifelse length farmers-who-did-that-this-week > 0[
        output-print reduce [(word ?1 ", " ?2)] map [item 0 ?] farmers-who-did-that-this-week
      ]
      [
        output-print "Nobody"
      ]
    ]
    output-print ""
  ]
end

to print-what-farmer-did
;  clear-output
;  output-print farmer-list
;  let actions-of-farmer filter [item 0 ? = farmer-list and item 2 ? = "do"] farmer-actions
;  let week-counter 1
;  foreach sort-by [item 1 ?1 < item 1 ?2] actions-of-farmer [
;    output-print (word "Week " week-counter)
;    output-print item 3 ?
;  ]
end

to print-counts-of-actions-per-farmer
  clear-output
  output-print "How many times people did what:"
  foreach things-people-did-in farmer-actions [
    let the-action ?
    output-print the-action
    foreach sort all-farmers[
      let the-farmer ?
      let the-count length filter [item 0 ? = the-farmer and item 2 ? = "do" and item 3 ? = the-action] farmer-actions
      output-print (word the-farmer " (" the-count ")")
    ]
  ]
end

;; reports all the things that people have done in the farmers-actions log
to-report things-people-did-in [alist]
  report remove-duplicates map [item 3 ?] filter [item 2 ? = "do"] alist
end

;; reports all weeks from the farmers-action log
to-report all-weeks-in [alist]
  report remove-duplicates map [item 1 ?] alist
end

to-report all-farmers
  report hubnet-clients-list
end

to-report how-many-did-what-when-in [alist]
  let outer (list)
  foreach things-people-did-in alist [
    let the-action ?
    let inner (list)
    foreach sort all-weeks-in alist [
      let the-week ?
      let the-count length filter [item 1 ? = the-week and item 2 ? = "do" and item 3 ? = the-action] alist
      set inner lput the-count inner
    ]
    set outer lput (list the-action inner) outer
  ]
  report outer
end


to show-how-many-did-what-when
  set-current-plot "Plot 2"
  clear-plot
  let the-colors base-colors
  foreach how-many-did-what-when-in farmer-actions [
    create-temporary-plot-pen first ?
    set-plot-pen-color first the-colors
    foreach last ? [
      plot ?
    ]
    set the-colors remove first the-colors the-colors
  ]
end

to show-who-was-seen-this-week
  ;; this had a bug that showed all farmers who were doing something, and not just the ones who are doing something AND were seen doing it
  output-print (word "For week " ticks)
  output-print "People who were observed this week:"
  foreach remove-duplicates sort [will-do] of seen-this-week [
    let farmers-who-did-this farmers with [will-do = ? and member? self seen-this-week]
    output-print (word ? ": " count farmers-who-did-this)
    output-print reduce [(word ?1 ", " ?2)] [user-id] of farmers-who-did-this
  ]
  if any? farmers with [not member? self seen-this-week][
    output-print "Famers not seen by anyone this week:"
    output-print reduce [(word ?1 ", " ?2)] [user-id] of farmers with [not member? self seen-this-week]
  ]
  output-print ""
end

to-report names-to-string-of [an-agentset]
  let names remove-duplicates [user-id] of an-agentset
  report reduce [(word ?1 ", " ?2)] names

end


to-report union [ts1 ts2]
  report (turtle-set ts1 ts2)
end


to create-bot
  create-farmers 1 [
  ]
end


to-report fence-fixers
  report farmers with [will-do = "Do: Repair Fences ($500)"]
end
to-report grass-sowers
  report farmers with [will-do = "Do: Sow Grass ($500)"]
end
to-report cow-herders
  report farmers with [will-do = "Do: Herd Cows"]
end
to-report grass-surveyors
    report farmers with [will-do = "Do: Survey Grass"]
end
to-report fence-inspectors
  report farmers with [will-do = "Do: Inspect Fences"]
end

to-report undecided
  report "Undecided"
end

to send-town-hall-meeting-message
  hubnet-send hubnet-clients-list  "Status" "Welcome to the weekly town hall meeting. Coordinate with your village, and decide what to do next week."
end

to set-color-from-hsb-list [alist]
  set color hsb item 0 alist item 1 alist item 2 alist
end

to-report wealth ; this returns a farmer's total wealth; 1500 per cow + their money
  report money + 1500 * count my-cows
end












;;; @Corey: This is how I imagine it will work, basically:
;;; Ideally I write this in my procedure - a list of tuples like this:
;
;[
;  ["Grass Amounts" [1 2 3]]
;  ["Milk Production" [5 1 3]]
;  ["State of Fences" [1.4 2.3 89.1]]
;
;]
;
;; in reality of course I'll send variables that are lists, which will resolve to the list in the second part of the tuple, but wanted
;; you to know what the data will look like:

to write-time-data
let the-data
(list
  ["Grass Amounts" [1 2 3]]
  ["Milk Production" [5 1 3]]
  ["State of Fences" [1.4 2.3 89.1]]
)
foreach the-data [
  ;; pseudo code, so commenting out
;  write first ?
;  write last ?
]
end

to write-person-data

end



;@corey: this is an old old. Don't worry about this one.
to-report historical-data;; depending on what we end up doing with the data, this should spit out either a CSV or a json with all these data
  let data-lists (list
    "actual-grass-amounts"
    "total-milk-production"
    "actual-fence-states"
    "money-in-the-bank"
    "count-cows-history"
    "who-herded"
    "who-monitored"
    "who-repaired"
    "who-sowed"
    "who-said-herded"
    "who-said-monitored"
    "who-said-repaired"
    "who-said-sowed"
    )
  ;; currently this returns lists of agentsets sometimes - in those cases, it should return a map [count ?]
  report map [(list ? (ifelse-value (is-agentset? item 1 run-result ?) [map [count  ?] runresult ?] [?]))] data-lists
end

















































;; post data to spreadsheet goes here



@#$#@#$#@
GRAPHICS-WINDOW
145
10
584
470
16
16
13.0
1
8
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
Week
30.0

OUTPUT
590
10
870
470
13

BUTTON
10
95
135
128
NIL
listen-to-clients
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
180
135
213
NIL
run-a-week
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
45
135
78
New Game!
setup-clean
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
875
495
1125
540
Shared Money
common-pool-bank
0
1
11

SLIDER
875
540
1125
573
$-amount
$-amount
0
1000
290
10
1
$
HORIZONTAL

CHOOSER
875
30
1057
75
plot-value
plot-value
"Total Milk Production" "Number of Cows" "Money in Bank" "Grass Amount" "State of Fences"
3

PLOT
875
75
1390
215
Plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS

PLOT
875
215
1390
355
Plot 2
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS

BUTTON
1185
30
1302
71
Show in Plot 2
show-in-plot 2
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1060
30
1185
71
Show in Plot 1
show-in-plot 1
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
875
575
1022
608
NIL
fine-them \"a-user\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
145
470
395
630
gini-coefficient
NIL
NIL
0.0
1.0
0.0
1.0
false
true
"" "clear-plot"
PENS
"Actual Wealth" 1.0 0 -13840069 true "" "if ticks > 0[foreach gini-points [plotxy first ? last ?]]"
"Equal Wealth" 1.0 0 -7500403 true "" "plotxy 0 0 plotxy 1 1"

BUTTON
1000
575
1125
610
Give to farmer
give-$-to-farmer \"user-id\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
955
475
1105
493
Money-related stuff
11
0.0
1

TEXTBOX
945
10
1095
28
Historical data
11
0.0
1

BUTTON
590
470
870
503
Show who says what
print-who-says-what
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
590
505
870
538
Show who did what
print-who-did-what
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
590
540
870
573
Show what this farmer did
print-what-farmer-did
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
590
575
870
608
Show who did what how many times
print-counts-of-actions-per-farmer
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1130
355
1390
400
How many did what and when?
show-how-many-did-what-when
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
215
135
248
setup test week data
ask farmers [\nset will-do one-of do-options\nset say-will-do one-of say-options\n]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
405
135
438
setup test run
;setup\nforeach n-values 25 [?]  [ add-farmer (word ?) true ] ask farmers [repeat 3 [buy-cow]]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
10
117
43
Start HubNet
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
20
280
112
313
test-week
ask farmers [\nset will-do one-of do-options\nset say-will-do one-of say-options\n]\nrun-a-week
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This model is inspired by Elinor Ostrom's work on how people manage resource systems and set up so-called institutions for collective action.

She positioned her work in opposition to The Tragedy of the Commons (TOC).

## HOW IT WORKS



## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fence
false
0
Line -6459832 false 30 255 30 105
Line -6459832 false 150 240 150 75
Line -6459832 false 255 225 255 60
Line -6459832 false 15 135 285 90
Line -6459832 false 15 165 285 120
Line -6459832 false 15 195 285 150
Line -6459832 false 15 225 285 180

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 6.0-PREVIEW-12-15
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
BUTTON
15
85
160
118
Say: Repair Fences ($500)
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
15
120
160
153
Say: Herd Cows
NIL
NIL
1
T
OBSERVER
NIL
NIL

MONITOR
15
320
160
369
# of Cows
NIL
0
1

MONITOR
165
320
325
369
$
NIL
0
1

BUTTON
15
285
325
318
Buy Cow ($1500)
NIL
NIL
1
T
OBSERVER
NIL
NIL

VIEW
335
65
835
565
0
0
0
1
1
1
1
1
0
1
1
1
-16
16
-16
16

MONITOR
15
10
835
59
Status
NIL
0
1

TEXTBOX
15
60
210
78
What you say you will do
15
0.0
1

TEXTBOX
15
160
175
178
What you actually do.
15
0.0
1

SLIDER
15
400
325
433
money-to-shared-bank
money-to-shared-bank
0
1000
50
1
1
NIL
HORIZONTAL

BUTTON
15
435
325
468
Donate
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
165
85
325
118
Say: Spread Fertilizer ($500)
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
15
185
160
218
Do: Repair Fences ($500)
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
15
220
160
253
Do: Herd Cows
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
165
185
325
218
Do: Spread Fertilizer ($500)
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
165
120
325
153
Say: Monitor Peers
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
165
220
325
253
Do: Monitor Peers
NIL
NIL
1
T
OBSERVER
NIL
NIL

TEXTBOX
15
260
165
278
Cows
15
0.0
1

TEXTBOX
15
375
65
393
Money
15
0.0
1

@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
1
@#$#@#$#@
