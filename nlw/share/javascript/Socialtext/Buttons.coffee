button_handler =
  "st-add-widget": ->
    st.dialog.show "opensocial-gallery",
      view: gadgets.container.view
      account_id: gadgets.container.viewer.primary_account_id or 0
  
  "st-edit-layout": ->
    $("#st-wiki-subnav-link-invite").hide()
    gadgets.container.enterEditMode()
  
  "st-save-layout": ->
    if gadgets.container.type == "account_dashboard"
      st.dialog.show "save-layout"
    else
      gadgets.container.saveAdminLayout success: ->
        $("#st-wiki-subnav-link-invite").show()
        gadgets.container.leaveEditMode()
  
  "st-cancel-layout": ->
    gadgets.container.loadLayout gadgets.container.base_url, ->
      $("#st-wiki-subnav-link-invite").show()
      gadgets.container.leaveEditMode()
  
  "st-revert-layout": ->
    $("#st-wiki-subnav-link-invite").show()
    gadgets.container.loadDefaults()
  
  "st-account-theme": ->
    location = "/nlw/control/account/#{
      gadgets.container.account_id
    }/theme?origin=/st/account/#{
      gadgets.container.account_id
    }/dashboard"
  
  "st-admin-dashboard": ->
    location = "/st/account/#{
      st.viewer.primary_account_id
    }/dashboard"
  
  "st-create-group": ->
    st.dialog.show "groups-create"
  
  "st-edit-group": ->
    location = "/st/edit_group/" + gadgets.container.group.id
  
  "st-leave-group": ->
    st.dialog.show "groups-leave", onConfirm: ->
      leave "/st/dashboard"
  
  "st-join-group": ->
    group = new Socialtext.Group(
      group_id: gadgets.container.group.id
      permission_set: gadgets.container.group.permission_set
    )
    group_data = users: [ user_id: st.viewer.user_id ]
    group.addMembers group_data, (data) ->
      if data.errors
        st.dialog.showError data.errors[0]
      else
        location = "/st/group/#{
          gadgets.container.group.id
        }?_=self-joined"
  
  "st-delete-group": ->
    st.dialog.show "groups-delete",
      group_id: gadgets.container.group.id
      group_name: gadgets.container.group.name
  
  "create-group": ->
    st.dialog.show "groups-save", {}
  
  "st-cancel-create-group": ->
    if gadgets?.container?.group
      location = "/st/group/#{gadgets.container.group.id}"
    else
      location = "/st/dashboard"
  
  "st-edit-profile": ->
    location = "/st/edit_profile"
  
  "st-revision-current": ->
    location = st.page.full_uri
  
  "st-revision-all": ->
  
  "st-revision-next": ->
  
  "st-revision-color": ->
    location = "[% script_name %]?action=revision_compare;page_name=[% page_uri %];new_revision_id=[% new_revision_id %];old_revision_id=[% old_revision_id %][% IF mode != 'source' %];mode=source[% END %]"
  
  "st-revision-view": ->
    location = "[% script_name %]?action=revision_compare;page_name=[% page_uri %];new_revision_id=[% new_revision_id %];old_revision_id=[% old_revision_id %][% IF mode != 'source' %];mode=source[% END %]"
  
  "st-wiki-subnav-link-invite": ->
    location = st.invite_url

Socialtext::buttons =
  show: (buttons) ->
    self = this
    buttons = buttons or []
    if st.invite_url
      buttons.unshift [ "st-wiki-subnav-link-invite", loc("nav.invite!") ]
    return unless buttons.length
    $.each buttons, (_, b) ->
      button_id = b[0]
      button_text = b[1]
      button_class = b[2]
      $button = $("<button/>").addClass(button_class).attr("id", button_id).button(label: button_text).click(button_handler[button_id] or ->
        throw new Error(button_id + " has no handler")
      ).appendTo("#globalNav .buttons")
    $ -> self.setup()
  
  setup: ->
    updateNetworksWidget = ->
      try
        gadgets.rpc.call "..", "pubsub", null, "publish", "update"
    $indicator = $("#st-watchperson-indicator")
    if $indicator.size()
      person = new Person(
        id: gadgets.container.owner.user_id
        best_full_name: gadgets.container.owner.name
        self: false
        onFollow: updateNetworksWidget
        onStopFollowing: updateNetworksWidget
      )
      person.loadWatchlist ->
        person.createFollowLink $indicator

$ -> $(".simple-button").button()
