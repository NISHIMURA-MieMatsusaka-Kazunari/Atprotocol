package AtProtocol::Chat;

use strict;
use warnings;
use utf8;
use Encode qw(encode decode);
use parent qw(AtProtocol);
use LWP::UserAgent;
use HTTP::Request;
use JSON;

use constant {
	##UserAgent
	USERAGENT	=> 'AtProtocol::Chat',
	##at protocol
	PDS_URI_A	=> 'https://bsky.social',
	#PDS_URI_A	=> 'https://scarletina.us-east.host.bsky.network',
	ACCEPT_LABELERS	=> 'did:plc:ar7c4by46qjdydhdevvrndac;redact',
	CHAT_PROXY	=> 'did:web:api.bsky.chat#bsky_chat',
	POST		=> 'app.bsky.feed.post',
	EMBED		=> 'app.bsky.embed.external',
	LANG		=> 'jp-JP',
};

# constructor
sub new {
	my $class		= shift;
	my $identifier 	= shift;
	my $password	= shift;
	my $directory	= shift;
	my $option		= shift;
	my $postType				= $option ? ($option->{postType}			? $option->{postType}		: POST)					: POST;
	my $embedType				= $option ? ($option->{embedType}			? $option->{embedType}		: EMBED)				: EMBED;
	$option->{userAgent}		= $option ? ($option->{userAgent}			? $option->{userAgent}		: USERAGENT)			: USERAGENT;
	$option->{pdsUri}			= $option ? ($option->{pdsUri}				? $option->{pdsUri}			: PDS_URI_A) 			: PDS_URI_A;
	$option->{acceptLabelers}	= $option ? ($option->{acceptLabelers}		? $option->{acceptLabelers}	: ACCEPT_LABELERS)		: ACCEPT_LABELERS;
	my $self;
	eval{
		if($identifier && $password && $directory){
			$self = AtProtocol->new($identifier, $password, $directory, $option) or die($!);
			$self->{postType}	= $postType;
			$self->{embedType}	= $embedType;
		}else{
			die("Err not set Identifier and Password.");
		}
	};
	if($@){
		chomp($@);
		$! = $@;
		return undef;
	}else{
		return bless $self, $class;
	}
}
# destructor
sub DESTROY {
	my $self = shift;
	$self->SUPER::DESTROY();
}
##  inheritance API getSession 
sub getSession {
	my $self = shift;
	my $option	= shift;
	my $ret			= undef;
	eval{
		$ret = $self->SUPER::getSession($option) or die($self->{err});
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

###  API chat.bsky.convo
# chat.bsky.convo.listConvos
sub convo_listConvos {
	my $self	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $limit		= $option ? ($option->{limit}		? $option->{limit}		: 20					): 20;
	my $cursor		= $option ? ($option->{cursor}		? $option->{cursor}		: undef					): undef;
	my $ret			= undef;
	eval{
		my %param = ();
		$limit	&& ($param{limit}	= $limit);
		$cursor	&& ($param{cursor}	= $cursor);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
			'GET', 
			$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.listConvos?'.$query,
			[
				'Authorization' => 'Bearer '.$self->{accessJwt}, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $option->{acceptLabelers},
				'Accept' => 'application/json'
			]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.listConvos?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_listConvos: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.deleteMessageForSelf
sub convo_deleteMessageForSelf {
	my $self		= shift;
	my $convoId		= shift;
	my $messageId	= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (
		convoId => $convoId, 
		messageId => $messageId
		);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
			'POST', 
			$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.deleteMessageForSelf',
			[
				'Authorization' => 'Bearer '.$self->{accessJwt}, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $option->{acceptLabelers},
				'Accept' => 'application/json'
			],
			$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.deleteMessageForSelf): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_deleteMessageForSelf: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.getConvoForMembers
sub convo_getConvoForMembers {
	my $self	= shift;
	my $members	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (members => $members);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
			'GET', 
			$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getConvoForMembers?'.$query,
			[
				'Authorization' => 'Bearer '.$self->{accessJwt}, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $option->{acceptLabelers},
				'Accept' => 'application/json'
			]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getConvoForMembers?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getConvoForMembers: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.getConvo
sub convo_getConvo {
	my $self	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
			'GET', 
			$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getConvo?'.$query,
			[
				'Authorization' => 'Bearer '.$self->{accessJwt}, 
				'atproto-proxy' => CHAT_PROXY,
				'atproto-accept-labelers' => $option->{acceptLabelers},
				'Accept' => 'application/json'
			]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getConvo?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getConvo: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.getLog
sub convo_getLog {
	my $self	= shift;
	my $cursor	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = ();
		$cursor && $param{cursor} = $cursor;
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getLog?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getLog?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getLog: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.getMessages
sub convo_getMessages {
	my $self	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $limit		= $option ? ($option->{limit}		? $option->{limit}		: undef					): undef;
	my $cursor		= $option ? ($option->{cursor}		? $option->{cursor}		: undef					): undef;
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		$limit	&& $param{limit}	= $limit;
		$cursor	&& $param{cursor}	= $cursor;
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.getMessages?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.getMessages?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_getMessages: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.leaveConvo
sub convo_leaveConvo {
	my $self	= shift;
	my $convoId	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.leaveConvo?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.leaveConvo?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_leaveConvo: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.listConvos
sub convo_listConvos {
	my $self	= shift;
	my $option	= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $limit		= $option ? ($option->{limit}		? $option->{limit}		: 20					): 20;
	my $cursor		= $option ? ($option->{cursor}		? $option->{cursor}		: undef					): undef;
	my $ret			= undef;
	eval{
		my %param = ();
		$limit	&& ($param{limit}	= $limit);
		$cursor	&& ($param{cursor}	= $cursor);
		my $query = $self->makeQuery(\%param);
		my $req = HTTP::Request->new (
		'GET', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.listConvos?'.$query,
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		]
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.listConvos?$$query): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_listConvos: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.muteConvo
sub convo_muteConvo {
	my $self		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.muteConvo',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.muteConvo): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_muteConvo: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.unmuteConvo
sub convo_muteConvo {
	my $self		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.unmuteConvo',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.unmuteConvo): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_unmuteConvo: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.sendMessageBatch
sub convo_sendMessageBatch {
	my $self		= shift;
	my $items		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (items => $items);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.sendMessageBatch',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.sendMessageBatch): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_sendMessageBatch: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}# chat.bsky.convo.sendMessage
sub convo_sendMessage {
	my $self		= shift;
	my $convoId		= shift;
	my $message		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId, message => $message);
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.sendMessage',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.sendMessage): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_sendMessage: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# chat.bsky.convo.updateRead
sub convo_updateRead {
	my $self		= shift;
	my $convoId		= shift;
	my $option		= shift;
	my $accessJwt	= $option ? ($option->{accessJwt}	? $option->{accessJwt}	: $self->{accessJwt}	): $self->{accessJwt};
	my $messageId	= $option ? ($option->{messageId}	? $option->{messageId}	: undef					): undef;
	my $ret			= undef;
	eval{
		my %param = (convoId => $convoId);
		$messageId && $param{messageId} = $messageId;
		my $jsont = encode_json(\%param);
		my $req = HTTP::Request->new (
		'POST', 
		$self->{serviceEndpoint}.'/xrpc/chat.bsky.convo.updateRead',
		[
		'Authorization' => 'Bearer '.$self->{accessJwt}, 
		'atproto-proxy' => CHAT_PROXY,
		'atproto-accept-labelers' => $option->{acceptLabelers},
		'Accept' => 'application/json'
		],
		$jsont
		)
		or die("Failed to initialize HTTP::Request(chat.bsky.convo.updateRead): $!");
		my $ua = LWP::UserAgent->new	or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent($self->{userAgent});
		my $res = $ua->request ($req)		or die("Failed to request: $!");
		my $sl	= $res->status_line;
		if($sl !~ /ok|Bad Request|Unauthorized/i){
			print $res->decoded_content."\n";
			die("Status is $sl.");
		}
		my $session	= decode_json($res->decoded_content);
		$self->{content} = $session;
		if($session->{error}){
			die("Err $session->{error} convo_updateRead: $session->{message}");
		}
		$ret = $session;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

### Utility subroutines
# make record form message
sub makeRecord {
	my $self	= shift;
	my $msg		= shift;
	my $option	= shift;
	my $collection	= $option ? ($option->{postType}	? $option->{postType}	: $self->{postType}	): $self->{postType};
	my $langs		= $option ? ($option->{langs}		? $option->{langs}		: [LANG]			): [LANG];
	#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$stime) = localtime(time());
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$stime) = gmtime(time());
	my $date = sprintf("%04d-%02d-%02dT%02d:%02d:%02d+00:00", $year+1900,$mon+1,$mday,$hour,$min,$sec);
	my $createAt	= $option ? ($option->{createAt}	? $option->{createAt}	: $date		): $date;
	my $ret			= undef;
	eval{
		my %record  = (
			"\$type" => $collection,
			text => $msg, 
			createdAt => $createAt, 
			langs => $langs,
		);
		my ($facets, $embed) = $self->makeFacetsEmbed($msg);
		if($facets && ref($facets) =~ /array/i && scalar(@$facets)){
			$record{facets} = $facets;
		}
		if($embed && ref($embed) =~ /hash/i && scalar(keys(%$embed))){
			$record{embed} = $embed;
		}
		$ret = \%record;
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}

# make Facets(URL, tag, mention) and Embed(ogp) from message
sub makeFacetsEmbed {
	my $self = shift;
	my $msg = shift;
	my $option	= shift;
	my $collection	= $option ? ($option->{embedType}	? $option->{embedType}	: $self->{embedType}	): $self->{embedType};
	my @facets = ();
	my %embed = ();
	#url
	my $f_ogp = 1;
	while($msg =~ /((https|http):\/\/[\-a-z0-9@:%\._+~#=]{1,256}\.[a-z0-9]{1,6}(\/[\-a-z0-9@:%\._+~#=\/]{1,256})*(\?[\S]+)*)/gi){
		my $uri = $1;
		push(@facets, {
			'index' => {
				'byteStart' => bytes::length($`), 
				'byteEnd' => bytes::length($`)+bytes::length($uri)
			}, 
			'features' => [{uri => $uri, "\$type" => 'app.bsky.richtext.facet#link'}]
		});
		## ogp
		$f_ogp or next;
		my $ogp = $self->getOpenGraphProtocol($uri)	or next;
		$f_ogp = undef;
		$embed{"\$type"} = $collection;
		$embed{external} = {
			uri => $uri,
			title => $ogp->{title},
			description => ($ogp->{description} ? $ogp->{description} : '')
		};
		if($ogp->{imgblob}){
			my $blob = $self->uploadBlob($ogp->{imgblob});
			if($blob && ref($blob) =~ /hash/i){
				$embed{external}{thumb} = $blob;
			}
		}
	}
	#tag
	while($msg =~ /\#([\S]+)/gi){
		push(@facets, {
			'index' => {
				'byteStart' => bytes::length($`), 
				'byteEnd' => bytes::length($`)+bytes::length($1)+1
			}, 
			'features' => [{tag => $1, "\$type" => 'app.bsky.richtext.facet#tag'}]
		});
	}
	#mention
	while($msg =~ /\@([0-9a-z\.\_\-]+)/gi){
		my $did = $self->resolveHandle($1) or next;
		push(@facets, {
			'index' => {
				'byteStart' => bytes::length($`), 
				'byteEnd' => bytes::length($`)+bytes::length($1)+1
			}, 
			'features' => [{did => $did, "\$type" => 'app.bsky.richtext.facet#mention'}]
		});
	}
	#my $facet_t = encode_json(\@facets);
	#print "facets: $facet_t\n";
	#my $embed_t = encode_json(\%embed);
	#print "embed: $embed_t.\n";
	return \@facets,\%embed;
}

# get OGP title,type,description,image_url,image_blob
sub getOpenGraphProtocol {
	my $self	= shift;
	my $uri		= shift;
	my $ret		= {};
	eval {
		my $server;
		unless($uri =~ /^(https{0,1}:\/\/([a-z]|[0-9]|[\-\._~:]|%[0-9a-f][0-9a-f])+?)(\/.+){0,1}$/i){
			die("not uri: $uri");
		}else{
			$server = $1;
		}
		my $req		= HTTP::Request->new ('GET', $uri)	or die("Failed to initialize HTTP::Request: $uri err: $!");
		my $ua		= LWP::UserAgent->new				or die("Failed to initialize LWP::UserAgent: $!");
		$ua->agent("Sarudokonetsystem");
		my $res		= $ua->request ($req)				or die("Failed to request: $!");
		my $sl = $res->status_line;
		unless($sl =~ /ok/i){
			die("GET $uri status is $sl.");
		}
		my $html	= $res->decoded_content;
		##get title
		if($html =~ /(<meta\s+[^>]*\s*property=['"]{0,1}og:title['"]{0,1}\s+[^>]*?>)/is){
			my $meta = $1;
			if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
				$ret->{title} = $1;
			}
		}
		if(!$ret->{title}){
			if($html =~ /<title>\s*(.+?)\s*<\/title>/i){
				$ret->{title} = $1;
			}else{
				die('cannot get ogp title');
			}
		}
		##get type
		if($html =~ /(<meta\s+[^>]*\s*property=['"]{0,1}og:type['"]{0,1}\s+[^>]*?>)/is){
			my $meta = $1;
			if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
				$ret->{type} = $1;
			}
		}
		##get description
		if($html =~ /(<meta\s+[^>]*\s*property=['"]{0,1}og:description['"]{0,1}\s+[^>]*?>)/is){
			my $meta = $1;
			if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
				$ret->{description} = $1;
			}
		}
		if(!$ret->{description}){
			if($html =~ /(<meta\s+[^>]*\s*name=['"]{0,1}description['"]{0,1}\s+[^>]*?>)/is){
				my $meta = $1;
				if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
					$ret->{description} = $1;
				}
			}
		}
		##get image_url
		if($html =~ /(<meta\s+[^>]*\s*property=['"]{0,1}og:image['"]{0,1}\s+[^>]*?>)/is){
			my $meta = $1;
			if($meta =~ /\scontent=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
				$ret->{imgurl} = $1;
				if($ret->{imgurl} !~ /^http/){
					$ret->{imgurl} = undef;
				}
			}
		}
		if(!$ret->{imgurl}){
			if($html =~ /(<link\s+[^>]*\s*rel=['"]{0,1}apple-touch-icon['"]{0,1}\s+[^>]*?>)/is){
				my $meta = $1;
				if($meta =~ /\href=['"]{0,1}(.+?)['"]{0,1}[ \\>]{1}/i){
					$ret->{imgurl} = $1;
					if($ret->{imgurl} !~ /^http/ && $ret->{imgurl} =~ /^\//){
						$ret->{imgurl} = $server.$ret->{imgurl};
					}else{
						$ret->{imgurl} = undef;
					}
				}
			}
		}
		if($ret->{imgurl}){
			$req	= HTTP::Request->new ('GET', $ret->{imgurl})	or die("Failed to initialize HTTP::Request: $ret->{imgurl} err: $!");
			$res	= $ua->request ($req)							or die("Failed to request: $!");
			$sl = $res->status_line;
			if($sl !~ /ok/i){
				die("GET $ret->{imgurl} status is $sl.");
			}
			$ret->{imgblob} = $res->content;
		}else{
			$ret->{imgurl} = undef;
			#	die('cannot get ogp image');
		}
	};
	if($@){
		chomp($@);
		$self->{err} = $@;
		$ret = undef;
	}
	return $ret;
}
# 
sub checkMagicByte {
	my $image	= shift;
	my $ret		= undef;
	my $jpg		= '^FFD8';
	my $bmp		= '^424D';
	my $gif		= '^474946';
	my $ico		= '^000001';
	my $png		= '^89504E47';
	my $tif		= '^(49492A00|4D4D002A)';
	my $webp	= '^52494646[0-9a-f]{8}57454250';
	my $avif	= '^00000018667479706C61766631';
	my $magicByte = unpack('H32', $image);
	#print $magicByte."\n";
	if($magicByte =~ /$jpg/i){
		$ret = 'image/jpeg';
	}elsif($magicByte =~ /$bmp/i){
		$ret = 'image/bmp';
	}elsif($magicByte =~ /$gif/i){
		$ret = 'image/gif';
	}elsif($magicByte =~ /$ico/i){
		$ret = 'image/x-icon';
	}elsif($magicByte =~ /$png/i){
		$ret = 'image/png';
	}elsif($magicByte =~ /$tif/i){
		$ret = 'image/tiff';
	}elsif($magicByte =~ /$webp/i){
		$ret = 'image/webp';
	}elsif($magicByte =~ /$avif/i){
		$ret = 'image/avif';
	}
	return $ret;
}
# post
# exclusive control. multi-process safe
# return hash(createRecord)
sub post {
	my $self	= shift;
	my $msg 	= shift;
	my $option	= shift;
	my $createAt	= $option ? ($option->{createAt}	? $option->{createAt}	: undef	): undef;
	my $collection	= $option ? ($option->{postType}	? $option->{postType}	: $self->{postType}	): $self->{postType};
	my $ret		= undef;
	eval{
		$self->getAccessToken()							or die("Err getAccessToken: $self->{err}");#start exclusive control
		my $option = {collection => $collection};
		$createAt or $option->{createAt} = $createAt;
		my $record = $self->makeRecord($msg, $option)	or die("Err makeRecord: $self->{err}");
		#my $jsont = encode_json($record);
		#print "Record:\n$jsont\n\n";
		$ret = $self->createRecord($record)				or die("Err createRecord: $self->{err}");
		$self->releaseAccessToken()						or die("Err releaseAccessToken: $self->{err}");#finish exclusive control
	};
	if($@){
		chomp $@;
		$self->{err} = $@;
		$self->releaseAccessToken();
		$ret = undef;
	}
	return $ret;
}

return 1;
