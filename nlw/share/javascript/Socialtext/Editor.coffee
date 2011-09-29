$ = jQuery
Socialtext::editor =
  insert_menu_extra_items: [null]
  ui_expand_setup: (->)
  pre_edit_hook: (wikiwyg_launcher, cleanup_callback) ->
    $.ajax
      type: "POST"
      url: location.pathname
      data:
        action: "edit_check_start"
        page_name: st.page.title
      
      dataType: "json"
      success: (data) ->
        return unless data.user_id
        if location.hash and /^#draft-\d+$/.test(location.hash)
          return if data.user_id == st.viewer.user_id

        {user_link, minutes_ago, user_business_card} = data
        time_ago = loc("ago.minutes=count", minutes_ago)
        $('#st-edit-check').remove()

        $('<div />', class: "lightbox", id: "st-edit-check")
          .append("<h3>#{loc('edit.warning')}</h3>")
          .append("<p>#{loc('page.opened-for-edit=user,ago', user_link, time_ago)}</p>")
          .append(user_business_card)
          .append(
            $('<div />', class:"""
              ui-dialog-buttonpane ui-widget-content ui-helper-clearfix
            """).append(
              $('<a />', href: '#', class: 'continue').text(loc('edit.force')).button()
            ).append(
              $('<a />', href: '#', class: 'close').text(loc('edit.return-to-page-view')).button()
            )
          ).appendTo('body')

        Socialtext::editor.showLightbox
          speed: 0
          content: "#st-edit-check"
          close: "#st-edit-check .close"
          callback: ->
            $("#bootstrap-loader").hide()
            bootstrap = false
            $("#st-edit-check .continue").removeClass("checked").unbind("click").click ->
              $.ajax
                type: "POST"
                url: location.pathname
                data:
                  action: "edit_start"
                  page_name: st.page.title
                  revision_id: st.page.revision_id
              
              $("#st-edit-check .continue").addClass "checked"
              Socialtext::editor.hideLightbox()
            
            $("#lightbox").one "lightbox-unload", ->
              unless $("#st-edit-check .continue").hasClass("checked")
                cleanup_callback?()
              $("#st-edit-check").remove()
    wikiwyg_launcher()

  showLightbox: (opts) ->
    if $('#lightbox').length
      try $("#lightbox").dialog('destroy')
      $('#lightbox').remove()
    $("<div />", id: "lightbox", css: {
      position: 'static'
      boxShadow: 'none'
      borderRadius: 'none'
    }).appendTo "body"
    opts.speed ?= 500
    opts.extraHeight ?= 60
    if opts.html
      opts.html = """
        <div style="display: block" class="lightbox">#{
          opts.html
        }</div>
      """
    $("#lightbox").css("width", opts.width || "520px").append(
      opts.html || $(opts.content).show()
    )
    title = opts.title || $('#lightbox span.title').text()
    $('#lightbox span.title').remove()
    $('#lightbox div.buttons input, #lightbox a.button').button()
    if opts.close
      $(opts.close).click ->
        Socialtext::editor.hideLightbox()
        return false
    opts.extraHeight += 60
    $('#lightbox').dialog
      modal: true
      zIndex: 2002
      resizable: false
      title: title
      close: ->
        $('#lightbox').triggerHandler 'lightbox-unload'
        Socialtext::editor.hideLightbox()
      width: $('#lightbox').width()
      height: Math.min($(window).height(), ($('#lightbox').height() + opts.extraHeight))
    $(opts.focus).focus() if opts.focus
    opts.callback?()
    return

  hideLightbox: () ->
    try $('#lightbox').dialog('close')
    try $('#lightbox').dialog('destroy')
    $("#lightbox").remove()

