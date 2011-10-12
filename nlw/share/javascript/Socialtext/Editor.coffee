$ = jQuery
Socialtext.prototype ?= {}
Socialtext::editor =
  insert_menu_extra_items: [null]
  ui_expand_setup: ->
    st.editor.ui_expand_on() if Cookie.get("ui_is_expanded")
    return
  ui_expand_toggle: ->
    if Cookie.get("ui_is_expanded")
      Cookie.del "ui_is_expanded"
      return st.editor.ui_expand_off()
    else
      Cookie.set "ui_is_expanded", "1"
      return st.editor.ui_expand_on()
  ui_expand_on: ->
    $("#st-edit-pagetools-expand, #st-pagetools-expand").attr(
      "title", loc("info.normal-view")
    ).text(loc("edit.normal")).addClass "contract"
    $("#st-edit-mode-container, #mainWrap").addClass "expanded"
    $(window).trigger "resize"
    unless $("body").css("overflow") == "hidden"
      st.editor._originalBodyOverflow = $("body").css("overflow")
      $("body").css "overflow", "hidden"
    unless $("html").css("overflow") == "hidden"
      st.editor._originalHTMLOverflow = $("html").css("overflow")
      $("html").css "overflow", "hidden"
    window.scrollTo 0, 0
    return
  ui_expand_off: ->
    $("#st-edit-pagetools-expand, #st-pagetools-expand").attr(
      "title", loc("info.expand-view")
    ).text(loc("edit.expand")).removeClass "contract"
    $("#st-edit-mode-container, #mainWrap").removeClass "expanded"
    $(window).trigger "resize"
    $("html").css "overflow", st.editor._originalHTMLOverflow || "auto"
    $("body").css "overflow", st.editor._originalBodyOverflow || "auto"
    return
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
          .append("<span class='title'>#{loc('edit.warning')}</span>")
          .append("<p>#{loc('page.opened-for-edit=user,ago', user_link, time_ago)}</p>")
          .append(user_business_card)
          .append("""
            <div class="buttons">
              <a href="#" class="continue">#{loc('edit.force')}</a>
              <a href="#" class="close">#{loc('edit.return-to-page-view')}</a>
            </div>
          """)
          .appendTo('body')
        $('#st-edit-check .buttons a').button()
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
            
            $("#lightbox").bind "dialogclose", ->
              unless $("#st-edit-check .continue").hasClass("checked")
                $('#st-display-mode-widgets').show()
                cleanup_callback?()
              $("#st-edit-check").remove()
    wikiwyg_launcher?()

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
    title = opts.title || $('#lightbox span.title, #lightbox div.title').text()
    $('#lightbox span.title, #lightbox div.title').remove()
    $('#lightbox div.buttons input, #lightbox a.button, #lightbox input.button').button()
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
        Socialtext::editor.hideLightbox()
      width: $('#lightbox').width()
      height: Math.min($(window).height(), ($('#lightbox').height() + opts.extraHeight))
    $(opts.focus).focus() if opts.focus
    opts.callback?()
    return

  hideLightbox: () ->
    $("#lightbox").triggerHandler('dialogclose')
    try $('#lightbox').dialog('destroy')
    $('div.lookaheadContainer').hide()
    $("#lightbox").remove()

  addNewTag: (tag) ->
    rand = ("" + Math.random()).replace(/\./, "")
    $("#st-page-editing-files").append $("<input type=\"hidden\" name=\"add_tag\" id=\"st-tagqueue-" + rand + "\" />").val(tag)
    $("#st-tagqueue-list").show()
    $("#st-tagqueue-list").append $("<span class=\"st-tagqueue-taglist-name\" id=\"st-taglist-" + rand + "\" />").text((if $(".st-tagqueue-taglist-name").size() then ", " else "") + tag)
    $("#st-taglist-" + rand).append $("<a href=\"#\" class=\"st-tagqueue-taglist-delete\" />").attr("title", loc("edit.remove=tag", tag)).click(->
      $("#st-taglist-" + rand).remove()
      $("#st-tagqueue-" + rand).remove()
      $("#st-tagqueue-list").hide()  unless $(".st-tagqueue-taglist-name").size()
      false
    ).html("<img src=\"/static/" + st.version + "/images/icons/close-black-8.png\" width=\"8\" height=\"8\" border=\"0\" style=\"padding: 4px\" />")
