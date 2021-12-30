( function ( $ ) {

	function siteHeaderFixed() {
		var $header = $( '.site-header' );

		$( window ).on( 'scroll', function() {
			if ( $header.height() < $( this ).scrollTop() ) {
				$( 'body' ).addClass( 'header-fixed' );
			} else {
				$( 'body' ).removeClass( 'header-fixed' );
			}
		} );
	}

	function mobileHeaderSearch() {
		$( '.main-header-container' ).append( '<button type="button" class="search-menu">검색</button>' );
		$( '.widget-area .widget_search' ).clone().appendTo( $( '.main-header-bar' ) );

		$( '.main-header-container .search-menu' ).on( 'click', function() {
			if ( $( '.main-header-bar .widget_search' ).is( ':hidden' ) ) {
				$( '.main-header-bar .widget_search' ).show();
			} else {
				$( '.main-header-bar .widget_search' ).hide();
			}
		} );
	}

	if ( $( '.site-header' ).length ) siteHeaderFixed();
	if ( $( '.widget-area' ).length ) mobileHeaderSearch();

} )( jQuery );
