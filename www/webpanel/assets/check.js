function formCheck(){
	var wifi_name = document.forms["etherisForm"]["wifi_name"];
	var psw = document.forms["etherisForm"]["password"];
	var etheris_name = document.forms["etherisForm"]["etheris_name"];
	var errContainer = document.getElementById("error_container");
	
	errContainer.innerHTML = "";
	errors = false;
	
	psw.className = 'normal';
	wifi_name.className = 'normal';	
	etheris_name.className = 'normal';
	errContainer.className = 'hidden';
	
	
	if (wifi_name.value==null || wifi_name.value==""){
		errorHandler(wifi_name,errContainer,"please choose a wiFi network name<br />");
	  	errors = true;
	}
	if (psw.value==null || psw.value==""){	
		errorHandler(psw,errContainer,"please choose a password<br />");
	  	errors = true;
	}else if (psw.value.length < 8){
		errorHandler(psw,errContainer,"password should be 8 char at least<br />");
		errors = true;
	}
	if (etheris_name.value==null ||etheris_name.value==""){	
		errorHandler(etheris_name,errContainer,"please choose a name for your Etheris<br />");
	  	errors = true;
	}
	
	if (errors) { return false; }

}

function errorHandler(el,er,msg){
	el.className = 'error';
	er.className = 'visible';
	er.innerHTML = '<p>'+er.innerHTML+msg+'</p>';
}