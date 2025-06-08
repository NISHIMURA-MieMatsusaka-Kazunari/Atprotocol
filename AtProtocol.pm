package AtProtocol;

use strict;
use warnings;
use utf8;
use Encode qw(encode decode);
use MIME::Base64;
use LWP::UserAgent;
use HTTP::Request;
use JSON;
use Fcntl ':flock'; # Import LOCK_* constants

use constant {
	##UserAgent
	USERAGENT	=> 'AtProtocol',
	##at protocol
	PDS_URI_A	=> 'https://bsky.social',
	##token_file_name
	FLOCK_FILE			=> 'flockAt_',
	ACCESS_TOKEN_FILE	=> 'atAcs_',
	REFRESH_TOKEN_FILE	=> 'atRef_',
	COLLECTION			=> 'app.bsky.feed.post',
	##デバッグ
	F_DEBUG			=> '',
};

# constructor
sub new {
	my $atProto		= shift;
	my $identifier 	= shift;
	my $password	= shift;
	my $directory	= shift;
	my $option		= shift;
	my $requestUri	= defined($option->{pdsUri})	? $option->{pdsUri}		: PDS_URI_A;
	my $userAgent	= defined($option->{userAgent})	? $option->{userAgent}	: USERAGENT;
	my $err = '';
	if($identifier && $password && $directory){
		my $self = {requestUri => $requestUri, identifier => $identifier, password => $password, directory => $directory, serviceEndpoint => $requestUri};
		return bless $self, $atProto;
	}else{
		@! = "Err not set Identifier or Password or directory.";
		return undef;
	}
}
# destructor
sub DESTROY {
	my $atProto = shift;
	$atProto->releaseAccessToken();
}

################# At Protocol API ##################
# com.atproto.server.createSession
sub createSession {
	my $atProto	= shift;
	my $option	= shift;
	my $identifier	= defined($option->{identifier})	? $option->{identifier}	: $atProto->{identifier};
	my $password	= defined($option->{password})		? $option->{password}	: $atProto->{password};
	my $ret			= undef;
	eval{
		my $jsont		= "{\"identifier\": \"$identifier\", \"password\": \"$password\"}";
		my $req = HTTP::Request->new ('POST', 
			$atProto->{requestUri}.'/xrpc/com.atproto.server.createSession', 
			['Content-Type' => 'application/json', 'Accept' => 'application/json'], 
			$jsont)
		or die("Failed to initialize HTTP::Request(com.atproto.server.createSession): $!");
		my $ua = LWP::UserAgent->new		or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent(USERAGENT);
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session 			= decode_json($res->decoded_content);
		$atProto->{content}	= $session;
		$atProto->{did}		= $session->{did}			or die("Err $session->{error} createSession1: $session->{message}");
		$atProto->{accessJwt}	= $session->{accessJwt}		or die("Err $session->{error} createSession2: $session->{message}");
		$atProto->{refreshJwt}	= $session->{refreshJwt}	or die("Err $session->{error} createSession3: $session->{message}");
		$ret = 1;
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.server.refreshSession
sub refreshSession {
	my $atProto	= shift;
	my $option	= shift;
	my $refreshJwt	= defined($option->{refreshJwt})	? $option->{refreshJwt}	: $atProto->{refreshJwt};
	#print $refreshJwt."\n";
	my $ret			= undef;
	eval{
		my $req = HTTP::Request->new ('POST', 
			$atProto->{requestUri}.'/xrpc/com.atproto.server.refreshSession', 
			['Authorization' => 'Bearer '.$refreshJwt, 'Accept' => 'application/json'])
		or die("Failed to initialize HTTP::Request(com.atproto.server.refreshSession:$refreshJwt)");
		my $ua = LWP::UserAgent->new	or die('Failed to initialize LWP::UserAgent');
		$ua->agent(USERAGENT);
		my $res = $ua->request ($req)		or die 'Failed to request(refreshSession)';
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session 			= decode_json($res->decoded_content);
		$atProto->{content}		= $session;
		$atProto->{did}			= $session->{did}			or die("Err $session->{error} refreshSession1: $session->{message}");
		$atProto->{accessJwt}	= $session->{accessJwt}		or die("Err $session->{error} refreshSession2: $session->{message}");
		$atProto->{refreshJwt}	= $session->{refreshJwt}	or die("Err $session->{error} refreshSession3: $session->{message}");
		$ret = 1;
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.server.deleteSession
sub deleteSession {
	my $atProto	= shift;
	my $option	= shift;
	my $refreshJwt	= defined($option->{refreshJwt})	? $option->{refreshJwt}	: $atProto->{refreshJwt};
	#print $refreshJwt."\n";
	my $ret			= undef;
	eval{
		my $req = HTTP::Request->new ('POST', 
			$atProto->{requestUri}.'/xrpc/com.atproto.server.deleteSession', 
			['Authorization' => 'Bearer '.$refreshJwt, 'Accept' => 'application/json'])
		or die("Failed to initialize HTTP::Request(com.atproto.server.deleteSession:$refreshJwt): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent(USERAGENT);
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session 		= decode_json($res->decoded_content);
		$session->{error}	&& die("Err $session->{error} deleteSession1: $session->{message}");
		$atProto->{content} = $session;
		$atProto->{did}		= undef;
		$atProto->{accessJwt}	= undef;
		$atProto->{refreshJwt}	= undef;
		$ret = 1;
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# com.atproto.server.getSession
sub getSession {
	my $atProto	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	#print $refreshJwt."\n";
	my $ret			= undef;
	eval{
		my $req = HTTP::Request->new ('GET', 
		$atProto->{requestUri}.'/xrpc/com.atproto.server.getSession', 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json'])
		or die("Failed to initialize HTTP::Request(com.atproto.server.getSession:$accessJwt): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent(USERAGENT);
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session 		= decode_json($res->decoded_content);
		$session->{error}	&& die("Err $session->{error} getSession1: $session->{message}");
		$ret = $session;
		## set serviceEndpoint
		$atProto->{serviceEndpoint} = $atProto->{requestUri};
		my @services = ();
		if(ref($ret->{didDoc}{service}) =~ /ARRAY/i){
			@services = @{$ret->{didDoc}{service}};
		}
		foreach my $service (@services){
			if($service->{type} =~ /AtprotoPersonalDataServer/i){
				$atProto->{serviceEndpoint} = $service->{serviceEndpoint};
				last;
			}
		}
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# com.atproto.identity.resolveHandle
sub resolveHandle {
	my $atProto	= shift;
	my $handle	= shift;
	my $option	= shift;
	my $accessJwt	= defined($option->{accessJwt})	? $option->{accessJwt}	: $atProto->{accessJwt};
	my $ret			= undef;
	eval{
		my $req = HTTP::Request->new ('GET', 
		$atProto->{requestUri}.'/xrpc/com.atproto.identity.resolveHandle?handle='.$handle, 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json'])
		or die("Failed to initialize HTTP::Request(com.atproto.identity.resolveHandle?handle=$handle): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($atProto->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session 	= decode_json($res->decoded_content);
		$atProto->{content} = $session;
		$ret			= $session->{did} or die("Err $session->{error}  resolveHandle1: $session->{message}");
	};
	if($@){
		chomp($@);
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

################# Perl Original (Wraper At Protocol)##################
# multi-process multi-thread safe。
sub getAccessToken {
	my $atProto	= shift;
	my $ret		= undef;
	my $flock	= undef;
	my $fh		= undef;
	eval{
		local $SIG{ALRM} = sub { die "timeout"; };							# set time out
		alarm(60);
		open($flock, '+<', $atProto->{directory}.FLOCK_FILE.$atProto->{identifier}.'.txt') or die('Cannot open '.$atProto->{directory}.FLOCK_FILE.$atProto->{identifier}.".txt: $!");
		my $old = select($flock); $| = 1; select($old);						# no buffering
		$atProto->{'flock'} = $flock;
		flock($flock, LOCK_EX) or die('Cannot lock '.FLOCK_FILE.": $!");
		alarm(0);															# unset  time out
		print $flock 'GetAccessToken:'.time();
		##read AccessToken file
		my $tmp = open $fh, '<', $atProto->{directory}.ACCESS_TOKEN_FILE.$atProto->{identifier}.'.json';
		my $accessTokenT = '';
		if($tmp){
			while (my $line = <$fh>) {
				$accessTokenT .= $line;
			}
			close $fh;
		}
		$fh = undef;
		my $accessTokenJ;
		if($accessTokenT){
			$accessTokenJ = decode_json($accessTokenT);
		}else{
			$accessTokenJ = {payload => {exp => 0}};
		}
		##if Life time of access token had less than 180 seconds left, call refreshSession or createSession
		if($accessTokenJ->{payload}{exp}-180 < time()){
			$tmp = open $fh, '<', $atProto->{directory}.REFRESH_TOKEN_FILE.$atProto->{identifier}.'.json';
			my $refreshTokenT = '';
			if($tmp){
				while (my $line = <$fh>) {
					$refreshTokenT .= $line;
				}
				close $fh;
			}
			#print $refreshTokenT."\n";
			$fh = undef;
			my $refreshTokenJ;
			if($refreshTokenT){
				$refreshTokenJ = decode_json($refreshTokenT);
			}else{
				$refreshTokenJ = {payload => {exp => 0}};
			}
			#print "exp:$refreshTokenJ->{payload}{exp}, time:".time()."\n";
			if($refreshTokenJ->{payload}{exp}-180 < time()){
				#print "createSession\n";
				$atProto->createSession() or die('Err createSession:'.$atProto->{err});
				$atProto->_writeSession() or die('Err _writeSession:'.$atProto->{err});
			}else{
				#print "refreshSession\n";
				$atProto->refreshSession({refreshJwt => $refreshTokenJ->{jwt}}) or die('Err createSession:'.$atProto->{err});
				$atProto->_writeSession() or die('Err _writeSession:'.$atProto->{err});
			}
		}else{
			$atProto->{accessJwt}	= $accessTokenJ->{jwt};
			$atProto->{did}		= $accessTokenJ->{did};
		}
		$ret = 1;
	};
	if($@){
		alarm(0);	# unset  time out
		chomp $@;
		$atProto->{err} = $@;
		releaseAccessToken();
		if($fh){
			close $fh;
		}
		$ret = undef;
	}
	return $ret;
}

# Exit exclusive control of Access Token without Disable Access Token
sub releaseAccessToken {
	my $atProto = shift;
	my $ret = undef;
	eval{
		my $flock = $atProto->{'flock'};
		if($flock){
			truncate($flock, 0);
			seek($flock, 0, 0);
			print $flock 'ReleaseAccessToken:'.time();
			close $flock or die "Cannot close flock: $!";
			#flock($flock, LOCK_UN) or die "Cannot unlock flock: $!";
			$atProto->{'flock'} = undef;
		}
		$ret = 1;
	};
	if($@){
		chomp $@;
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# Exit exclusive control of Access Token with Disable Access Token
sub deleteAccessToken {
	my $atProto = shift;
	my $ret = undef;
	my $fh = undef;
	eval{
		$atProto->deleteSession() or die($atProto->{err});
		my $a;
		$a	= _filePrint($atProto->{directory}.ACCESS_TOKEN_FILE.$atProto->{identifier}.'.json',	'');
		$a	= _filePrint($atProto->{directory}.REFRESH_TOKEN_FILE.$atProto->{identifier}.'.json',	'');
		$atProto->releaseAccessToken() or die($atProto->{err});
		$ret = 1;
	};
	if($@){
		chomp $@;
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

## hash to Query for GET
sub makeQuery {
	my $atProto	= shift;
	my $ref_p	= shift;
	my $ret		= '';
	if(ref($ref_p) =~ /hash/i){
		foreach my $key (keys(%$ref_p)) {
			if(ref($ref_p->{$key}) =~ /array/i){
				foreach my $value (@{$ref_p->{$key}}){
					$ret	.= "$key=$value&";
				}
			}else{
				$ret	.= "$key=$ref_p->{$key}&";
			}
		}
	}else{
		$atProto->{err} = 'makeQuery need hash refference'
	}
	return $ret;
}

# write Jwt,did information to ACCESS_TOKEN_FILE
sub _writeSession {
	my $atProto = shift;
	my $option = shift;
	my $ret = 1;
	eval{
		my $flock = $atProto->{'flock'} or die('Err not set FLOCK');
		my $refreshJwt	= defined($option->{refreshJwt})	? $option->{refreshJwt}	: $atProto->{refreshJwt}
			or die('Err not set refreshJwt');
		my $accessJwt	= defined($option->{accessJwt})		? $option->{accessJwt}	: $atProto->{accessJwt}
			or die('Err not set accessJwt');
		my $did			= defined($option->{did})			? $option->{did}		: $atProto->{did}
			or die('Err not set did');
		my @refreshJwtA		= split(/\./, $refreshJwt);
		my $refreshPayload	= decode_json(decode_base64($refreshJwtA[1]));
		my $refreshSessionJ	= {payload => $refreshPayload	, jwt => $refreshJwt	, did => $did};
		my $refreshSessionT	= encode_json($refreshSessionJ);
		my @accessJwtA		= split(/\./, $accessJwt);
		my $accessPayload	= decode_json(decode_base64($accessJwtA[1]));
		my $accessSessionJ	= {payload => $accessPayload	, jwt => $accessJwt		, did => $did};
		my $accessSessionT	= encode_json($accessSessionJ);
		my $a;
		$a	= _filePrint($atProto->{directory}.ACCESS_TOKEN_FILE.$atProto->{identifier}.'.json',	$accessSessionT);
		if($a->{err}){die $a->{err};}
		$a	= _filePrint($atProto->{directory}.REFRESH_TOKEN_FILE.$atProto->{identifier}.'.json',	$refreshSessionT);
		if($a->{err}){die $a->{err};}
	};
	if($@){
		chomp $@;
		$atProto->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

sub _filePrint {
	my $filename	= shift;
	my $data		= shift;
	my $option		= shift;
	my $tmp = open my $fh, '>', $filename;
	if($tmp){
		if($option && $option->{binmode}){
			binmode $fh;
		}
		print $fh $data;
		close $fh;
		return {err => ''};
	}else{
		return {err => "Cannot open $filename: $!"};
	}
}

return 1;