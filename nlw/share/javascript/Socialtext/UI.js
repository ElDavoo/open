(function($) {
 
$('input.initial').live('click', function() {
  $(this).removeClass('initial').val('');
});

})(jQuery);
