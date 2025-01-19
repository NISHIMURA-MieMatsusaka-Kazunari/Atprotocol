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
	my $class		= shift;
	my $identifier 	= shift;
	my $password	= shift;
	my $directory	= shift;
	my $option		= shift;
	my $requestUri	= $option ? ($option->{pdsUri}		? $option->{pdsUri}		: PDS_URI_A) : PDS_URI_A;
	my $userAgent	= $option ? ($option->{userAgent}	? $option->{userAgent}	: USERAGENT) : USERAGENT;
	my $err = '';
	if($identifier && $password && $directory){
		my $self = {requestUri => $requestUri, identifier => $identifier, password => $password, directory => $directory, serviceEndpoint => $requestUri};
		return bless $self, $class;
	}else{
		@! = "Err not set Identifier or Password or directory.";
		return undef;
	}
}
# destructor
sub DESTROY {
	my $self = shift;
	$self->releaseAccessToken();
}

################# At Protocol API ##################
# com.atproto.server.createSession
sub createSession {
	my $self	= shift;
	my $option	= shift;
	my $identifier	= $option ? ($option->{identifier}	? $option->{identifier}	: $self->{identifier}	): $self->{identifier};
	my $password	= $option ? ($option->{password}	? $option->{password}	: $self->{password}		): $self->{password};
	my $ret			= undef;
	eval{
		my $jsont		= "{\"identifier\": \"$identifier\", \"password\": \"$password\"}";
		my $req = HTTP::Request->new ('POST', 
			$self->{requestUri}.'/xrpc/com.atproto.server.createSession', 
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
		$self->{content}	= $session;
		$self->{did}		= $session->{did}			or die("Err $session->{error} createSession1: $session->{message}");
		$self->{accessJwt}	= $session->{accessJwt}		or die("Err $session->{error} createSession2: $session->{message}");
		$self->{refreshJwt}	= $session->{refreshJwt}	or die("Err $session->{error} createSession3: $session->{message}");
		$ret = 1;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.server.refreshSession
sub refreshSession {
	my $self	= shift;
	my $option	= shift;
	my $refreshJwt	= $option ? ($option->{refreshJwt}	? $option->{refreshJwt}	: $self->{refreshJwt})	:  $self->{refreshJwt};
	#print $refreshJwt."\n";
	my $ret			= undef;
	eval{
		my $req = HTTP::Request->new ('POST', 
			$self->{requestUri}.'/xrpc/com.atproto.server.refreshSession', 
			['Authorization' => 'Bearer '.$refreshJwt, 'Accept' => 'application/json'])
		or die("Failed to initialize HTTP::Request(com.atproto.server.refreshSession:$refreshJwt)");
		my $ua = LWP::UserAgent->new	or die('Failed to initialize LWP::UserAgent');
		$ua->agent(USERAGENT);
		my $res = $ua->request ($req)		or die 'Failed to request(refreshSession)';
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session 		= decode_json($res->decoded_content);
		$self->{content}	= $session;
		$self->{did}		= $session->{did}			or die("Err $session->{error} refreshSession1: $session->{message}");
		$self->{accessJwt}	= $session->{accessJwt}		or die("Err $session->{error} refreshSession2: $session->{message}");
		$self->{refreshJwt}	= $session->{refreshJwt}	or die("Err $session->{error} refreshSession3: $session->{message}");
		$ret = 1;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# com.atproto.server.deleteSession
sub deleteSession {
	my $self	= shift;
	my $option	= shift;
	my $refreshJwt	= $option ? ($option->{refreshJwt}	? $option->{refreshJwt}	: $self->{refreshJwt})	:  $self->{refreshJwt};
	#print $refreshJwt."\n";
	my $ret			= undef;
	eval{
		my $req = HTTP::Request->new ('POST', 
			$self->{requestUri}.'/xrpc/com.atproto.server.deleteSession', 
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
		$self->{content} = $session;
		$self->{did}		= undef;
		$self->{accessJwt}	= undef;
		$self->{refreshJwt}	= undef;
		$ret = 1;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# com.atproto.server.getSession
sub getSession {
	my $self	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	#print $refreshJwt."\n";
	my $ret			= undef;
	eval{
		my $req = HTTP::Request->new ('GET', 
		$self->{requestUri}.'/xrpc/com.atproto.server.getSession', 
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
		$self->{serviceEndpoint} = $self->{requestUri};
		my @services = ();
		if(ref($ret->{didDoc}{service}) =~ /ARRAY/i){
			@services = @{$ret->{didDoc}{service}};
		}
		foreach my $service (@services){
			if($service->{type} =~ /AtprotoPersonalDataServer/i){
				$self->{serviceEndpoint} = $service->{serviceEndpoint};
				last;
			}
		}
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# com.atproto.identity.resolveHandle
sub resolveHandle {
	my $self	= shift;
	my $handle	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	):  $self->{accessJwt};
	my $ret			= undef;
	eval{
		my $jsont		= "{\"handle\": \"$handle\"}";
		my $req = HTTP::Request->new ('GET', 
		$self->{requestUri}.'/xrpc/com.atproto.identity.resolveHandle?handle='.$handle, 
		['Authorization' => 'Bearer '.$accessJwt, 'Accept' => 'application/json'])
		or die("Failed to initialize HTTP::Request(com.atproto.identity.resolveHandle?handle=$handle): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			die("Status is $sl.");
		}
		my $session 	= decode_json($res->decoded_content);
		$self->{content} = $session;
		$ret			= $session->{did} or die("Err $session->{error}  resolveHandle1: $session->{message}");
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

################# Perl Original (Wraper At Protocol)##################
# multi-process multi-thread safe。
sub getAccessToken {
	my $self	= shift;
	my $ret		= undef;
	my $flock	= undef;
	my $fh		= undef;
	eval{
		local $SIG{ALRM} = sub { die "timeout"; };							# set time out
		alarm(5);
		open($flock, '>', $self->{directory}.FLOCK_FILE.$self->{identifier}.'.txt') or die('Cannot open '.$self->{directory}.FLOCK_FILE.$self->{identifier}.".txt: $!");
		$self->{'flock'} = $flock;
		flock($flock, LOCK_EX) or die('Cannot lock '.FLOCK_FILE.": $!");
		alarm(0);															# unset  time out
		print $flock 'GetAccessToken:'.time();
		##read AccessToken file
		my $tmp = open $fh, '<', $self->{directory}.ACCESS_TOKEN_FILE.$self->{identifier}.'.json';
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
			$tmp = open $fh, '<', $self->{directory}.REFRESH_TOKEN_FILE.$self->{identifier}.'.json';
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
				$self->createSession() or die('Err createSession:'.$self->{err});
				$self->_writeSession() or die('Err _writeSession:'.$self->{err});
			}else{
				#print "refreshSession\n";
				$self->refreshSession({refreshJwt => $refreshTokenJ->{jwt}}) or die('Err createSession:'.$self->{err});
				$self->_writeSession() or die('Err _writeSession:'.$self->{err});
			}
		}else{
			$self->{accessJwt}	= $accessTokenJ->{jwt};
			$self->{did}		= $accessTokenJ->{did};
		}
		$ret = 1;
	};
	if($@){
		alarm(0);	# unset  time out
		chomp $@;
		$self->{err} = $@;
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
	my $self = shift;
	my $ret = undef;
	eval{
		my $flock = $self->{'flock'};
		if($flock){
			print $flock 'ReleaseAccessToken:'.time();
			close $flock or die "Cannot close flock: $!";
			#flock($flock, LOCK_UN) or die "Cannot unlock flock: $!";
			$self->{'flock'} = undef;
		}
		$ret = 1;
	};
	if($@){
		chomp $@;
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# Exit exclusive control of Access Token with Disable Access Token
sub deleteAccessToken {
	my $self = shift;
	my $ret = undef;
	my $fh = undef;
	eval{
		$self->deleteSession() or die($self->{err});
		my $a;
		$a	= _filePrint($self->{directory}.ACCESS_TOKEN_FILE.$self->{identifier}.'.json',	'');
		$a	= _filePrint($self->{directory}.REFRESH_TOKEN_FILE.$self->{identifier}.'.json',	'');
		$self->releaseAccessToken() or die($self->{err});
		$ret = 1;
	};
	if($@){
		chomp $@;
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

## hash to Query for GET
sub makeQuery {
	my $self	= shift;
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
		$self->{err} = 'makeQuery need hash refference'
	}
	return $ret;
}

# write Jwt,did information to ACCESS_TOKEN_FILE
sub _writeSession {
	my $self = shift;
	my $option = shift;
	my $ret = 1;
	eval{
		my $flock = $self->{'flock'} or die('Err not set FLOCK');
		my $refreshJwt	= $option ? ($option->{refreshJwt}	? $option->{refreshJwt}	: $self->{refreshJwt}	):  $self->{refreshJwt}
			or die('Err not set refreshJwt');
		my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	):  $self->{accessJwt}
			or die('Err not set accessJwt');
		my $did			= $option ? ($option->{did}			? $option->{did}		: $self->{did}			):  $self->{did}
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
		$a	= _filePrint($self->{directory}.ACCESS_TOKEN_FILE.$self->{identifier}.'.json',	$accessSessionT);
		if($a->{err}){die $a->{err};}
		$a	= _filePrint($self->{directory}.REFRESH_TOKEN_FILE.$self->{identifier}.'.json',	$refreshSessionT);
		if($a->{err}){die $a->{err};}
	};
	if($@){
		chomp $@;
		$self->{err} = $@;
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