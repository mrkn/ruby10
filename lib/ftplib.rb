### ftplib.rb			-*- Mode: ruby; tab-width: 8; -*-

## $Revision: 1.5 $
## $Date: 1997/09/16 08:03:31 $
## by maeda shugo <shugo@po.aianet.ne.jp>

### Code:

require "socket"
require "sync" if defined? Thread

class FTPError < Exception; end
class FTPReplyError < FTPError; end
class FTPTempError < FTPError; end
class FTPPermError < FTPError; end
class FTPProtoError < FTPError; end

class FTP
   
  RCS_ID = '$Id: ftplib.rb,v 1.5 1997/09/16 08:03:31 shugo Exp $'
   
   FTP_PORT = 21
   CRLF = "\r\n"
   
   attr :passive, TRUE
   attr :return_code, TRUE
   attr :debug_mode, TRUE
   attr :welcome
   attr :lastresp
   
   THREAD_SAFE = defined?(Thread) != FALSE
   
   if THREAD_SAFE
      def synchronize(mode = :EX)
	 if @sync
	    @sync.synchronize(mode) do
	       yield
	    end
	 end
      end
      
      def sock_synchronize(mode = :EX)
	 if @sock
	    @sock.synchronize(mode) do
	       yield
	    end
	 end
      end
   else
      def synchronize(mode = :EX)
	 yield
      end
      
      def sock_synchronize(mode = :EX)
	 yield
      end
   end
   private :sock_synchronize
   
   def FTP.open(host, user = nil, passwd = nil, acct = nil)
      new(host, user, passwd, acct)
   end
    
   def initialize(host = nil, user = nil,
		  passwd = nil, acct = nil)
      if THREAD_SAFE
	 @sync = Sync.new
      end
      @passive = FALSE
      @return_code = "\n"
      @debug_mode = FALSE
      if host
	 connect(host)
	 if user
	    login(user, passwd, acct)
	 end
      end
   end
   
   def open_socket(host, port)
      if defined? SOCKSsocket and ENV["SOCKS_SERVER"]
	 @passive = TRUE
	 SOCKSsocket.open(host, port)
      else
	 TCPsocket.open(host, port)
      end
   end
   private :open_socket
   
   def connect(host, port = FTP_PORT)
      if @debug_mode
	 print "connect: ", host, ", ", port, "\n"
      end
      synchronize do
	 @sock = open_socket(host, port)
	 if THREAD_SAFE
	    @sock.extend Sync_m
	 end
	 voidresp
      end
   end
   
   def sanitize(s)
      if s =~ /^PASS /i
	 s[0, 5] + "*" * (s.length - 5)
      else
	 s
      end
   end
   private :sanitize
   
   def putline(line)
      if @debug_mode
	 print "put: ", sanitize(line), "\n"
      end
      line = line + CRLF
      @sock.write(line)
   end
   private :putline
   
   def getline
      line = @sock.readline # if get EOF, raise EOFError
      if line[-2, 2] == CRLF
	 line = line[0 .. -3]
      elsif line[-1] == ?\r or
	    line[-1] == ?\n
	 line = line[0 .. -2]
      end
      if @debug_mode
	 print "get: ", sanitize(line), "\n"
      end
      line
   end
   private :getline
   
   def getmultiline
      line = getline
      buff = line
      if line[3] == ?-
	 code = line[0, 3]
	 begin
	    line = getline
	    buff << "\n" << line
	 end until line[0, 3] == code and line[3] != ?-
      end
      buff << "\n"
   end
   private :getmultiline

   def getresp
      resp = getmultiline
      @lastresp = resp[0, 3]
      c = resp[0]
      case c
      when ?1, ?2, ?3
	 return resp
      when ?4
	 raise FTPTempError, resp
      when ?5
	 raise FTPPermError, resp
      else
	 raise FTPProtoError, resp
      end
   end
   private :getresp
   
   def voidresp
      resp = getresp
      if resp[0] != ?2
	 raise FTPReplyError, resp
      end
   end
   private :voidresp
   
   def sendcmd(cmd)
      synchronize do
	 sock_synchronize do
	    putline(cmd)
	    getresp
	 end
      end
   end
   
   def voidcmd(cmd)
      synchronize do
	 sock_synchronize do
	    putline(cmd)
	    voidresp
	 end
      end
      nil
   end
   
   def sendport(host, port)
      hbytes = host.split(".")
      pbytes = [port / 256, port % 256]
      bytes = hbytes + pbytes
      cmd = "PORT " + bytes.join(",")
      voidcmd(cmd)
   end
   private :sendport
   
   def makeport
      sock = TCPserver.open(0)
      port = sock.addr[1]
      host = TCPsocket.getaddress(@sock.addr[2])
      resp = sendport(host, port)
      sock
   end
   private :makeport
   
   def transfercmd(cmd)
      if @passive
	 host, port = parse227(sendcmd("PASV"))
	 conn = open_socket(host, port)
	 resp = sendcmd(cmd)
	 if resp[0] != ?1
	    raise FTPReplyError, resp
	 end
      else
	 sock = makeport
	 resp = sendcmd(cmd)
	 if resp[0] != ?1
	    raise FTPReplyError, resp
	 end
	 conn = sock.accept
      end
      conn
   end
   private :transfercmd
   
   def getaddress
      thishost = Socket.gethostname
      if not thishost.index(".")
	 thishost = Socket.gethostbyname(thishost)[0]
      end
      if ENV.has_key?("LOGNAME")
	 realuser = ENV["LOGNAME"]
      elsif ENV.has_key?("USER")
	 realuser = ENV["USER"]
      else
	 realuser = "anonymous"
      end
      realuser + "@" + thishost
   end
   private :getaddress
   
   def login(user = "anonymous", passwd = nil, acct = nil)
      if user == "anonymous" and passwd == nil
	 passwd = getaddress
      end
      
      resp = ""
      synchronize do
	 resp = sendcmd('USER ' + user)
	 if resp[0] == ?3
	    resp = sendcmd('PASS ' + passwd)
	 end
	 if resp[0] == ?3
	    resp = sendcmd('ACCT ' + acct)
	 end
      end
      if resp[0] != ?2
	 raise FTPReplyError, resp
      end
      @welcome = resp
   end
   
   def retrbinary(cmd, blocksize, callback = Proc.new)
      synchronize do
	 voidcmd("TYPE I")
	 conn = transfercmd(cmd)
	 while TRUE
	    data = conn.read(blocksize)
	    break if data == nil
	    callback.call(data)
	 end
	 conn.close
	 voidresp
      end
   end
   
   def retrlines(cmd, callback = nil)
      if iterator?
	 callback = Proc.new
      elsif not callback.is_a?(Proc)
	 callback = Proc.new {|line| print line, "\n"}
      end
      synchronize do
	 voidcmd("TYPE A")
	 conn = transfercmd(cmd)
	 while TRUE
	    line = conn.gets
	    break if line == nil
	    if line[-2, 2] == CRLF
	       line = line[0 .. -3]
	    elsif line[-1] == ?\n
	       line = line[0 .. -2]
	    end
	    callback.call(line)
	 end
	 conn.close
	 voidresp
      end
   end
   
   def storbinary(cmd, file, blocksize, callback = nil)
      if iterator?
	 callback = Proc.new
      end
      use_callback = callback.is_a?(Proc)
      synchronize do
	 voidcmd("TYPE I")
	 conn = transfercmd(cmd)
	 while TRUE
	    buf = file.read(blocksize)
	    break if buf == nil
	    conn.write(buf)
	    if use_callback
	       callback.call(buf)
	    end
	 end
	 conn.close
	 voidresp
      end
   end
   
   def storlines(cmd, file, callback = nil)
      if iterator?
	 callback = Proc.new
      end
      use_callback = callback.is_a?(Proc)
      synchronize do
	 voidcmd("TYPE A")
	 conn = transfercmd(cmd)
	 while TRUE
	    buf = file.gets
	    break if buf == nil
	    if buf[-2, 2] != CRLF
	       if buf[-1] == ?\r or
		     buf[-1] == ?\n
		  buf = buf[0 .. -2]
	       end
	       buf = buf + CRLF
	    end
	    conn.write(buf)
	    if use_callback
	       callback.call(buf)
	    end
	 end
	 conn.close
	 voidresp
      end
   end
   
   def getbinaryfile(remotefile, localfile,
		     blocksize, callback = nil)
      if iterator?
	 callback = Proc.new
      end
      use_callback = callback.is_a?(Proc)
      f = open(localfile, "w")
      begin
      f.binmode
	 retrbinary("RETR " + remotefile, blocksize) do |data|
	    f.write(data)
	    if use_callback
	       callback.call(data)
	    end
	 end
      ensure
	 f.close
      end
   end
   
   def gettextfile(remotefile, localfile, callback = nil)
      if iterator?
	 callback = Proc.new
      end
      use_callback = callback.is_a?(Proc)
      f = open(localfile, "w")
      begin
	 retrlines("RETR " + remotefile) do |line|
	    line = line + @return_code
	    f.write(line)
	    if use_callback
	       callback.call(line)
	    end
	 end
      ensure
	 f.close
      end
   end
   
   def putbinaryfile(localfile, remotefile,
		     blocksize, callback = nil)
      if iterator?
	 callback = Proc.new
      end
      use_callback = callback.is_a?(Proc)
      f = open(localfile)
      begin
      f.binmode
	 storbinary("STOR " + remotefile, f, blocksize) do |data|
	    if use_callback
	       callback.call(data)
	    end
	 end
      ensure
	 f.close
      end
   end
   
   def puttextfile(localfile, remotefile, callback = nil)
      if iterator?
	 callback = Proc.new
      end
      use_callback = callback.is_a?(Proc)
      f = open(localfile)
      begin
	 storlines("STOR " + remotefile, f) do |line|
	    if use_callback
	       callback.call(line)
	    end
	 end
      ensure
	 f.close
      end
   end
   
   def acct(account)
      cmd = "ACCT " + account
      voidcmd(cmd)
   end
   
   def nlst(dir = nil)
      cmd = "NLST"
      if dir
	 cmd = cmd + " " + dir
      end
      files = []
      retrlines(cmd) do |line|
	 files.push(line)
      end
      files
   end
   
   def list(*args)
      cmd = "LIST"
      if iterator?
	 callback = Proc.new
      elsif args[-1].is_a?(Proc)
	 callback = args.pop
      else
	 callback = nil
      end
      args.each do |arg|
	 cmd = cmd + " " + arg
      end
      retrlines(cmd, callback)
   end
   alias ls list
   alias dir list
   
   def rename(fromname, toname)
      resp = sendcmd("RNFR " + fromname)
      if resp[0] != ?3
	 raise FTPReplyError, resp
      end
      voidcmd("RNTO " + toname)
   end
   
   def delete(filename)
      resp = sendcmd("DELE " + filename)
      if resp[0, 3] == "250"
	 return
      elsif resp[0] == ?5
	 raise FTPPermError, resp
      else
	 raise FTPReplyError, resp
      end
   end
   
   def chdir(dirname)
      if dirname == ".."
	 begin
	    voidcmd("CDUP")
	    return
	 rescue FTPPermError
	    if $![0, 3] != "500"
	       raise FTPPermError, $!
	    end
	 end
      end
      cmd = "CWD " + dirname
      voidcmd(cmd)
   end
   
   def size(filename)
      resp = sendcmd("SIZE " + filename)
      if resp[0, 3] == "213"
	 return Integer(resp[3 .. -1].strip)
      end
   end
   
   def mkdir(dirname)
      resp = sendcmd("MKD " + dirname)
      return parse257(resp)
   end
   
   def rmdir(dirname)
      voidcmd("RMD " + dirname)
   end
   
   def pwd
      resp = sendcmd("PWD")
      return parse257(resp)
   end
   alias getdir pwd
   
   def system
      resp = sendcmd("SYST")
      if resp[0, 3] != "215"
	 raise FTPReplyError, resp
      end
      return resp[4 .. -1]
   end
   
   def abort
      line = "ABOR" + CRLF
      resp = ""
      sock_synchronize do
	 print "put: ABOR\n" if @debug_mode
	 @sock.send(line, Socket::MSG_OOB)
	 resp = getmultiline
      end
      unless ["426", "226", "225"].include?(resp[0, 3])
	 raise FTPProtoError, resp
      end
      resp
   end
   
   def status
      line = "STAT" + CRLF
      resp = ""
      sock_synchronize do
	 print "put: STAT\n" if @debug_mode
	 @sock.send(line, Socket::MSG_OOB)
	 resp = getresp
      end
      resp
   end
   
   def help(arg = nil)
      cmd = "HELP"
      if arg
	 cmd = cmd + " " + arg
      end
      sendcmd(cmd)
   end
   
   def quit
      voidcmd("QUIT")
   end
   
   def close
      @sock.close if @sock and not @sock.closed?
   end
   
  def closed?
    @sock == nil or @sock.closed?
  end
  
   def parse227(resp)
      if resp[0, 3] != "227"
	 raise FTPReplyError, resp
      end
      left = resp.index("(")
      right = resp.index(")")
      if left == nil or right == nil
	 raise FTPProtoError, resp
      end
      numbers = resp[left + 1 .. right - 1].split(",")
      if numbers.length != 6
	 raise FTPProtoError, resp
      end
      host = numbers[0, 4].join(".")
      port = (Integer(numbers[4]) << 8) + Integer(numbers[5])
      return host, port
   end
   private :parse227
   
   def parse257(resp)
      if resp[0, 3] != "257"
	 raise FTPReplyError, resp
      end
      if resp[3, 2] != ' "'
	 return ""
      end
      dirname = ""
      i = 5
      n = resp.length
      while i < n
	 c = resp[i, 1]
	 i = i + 1
	 if c == '"'
	    if i > n or resp[i, 1] != '"'
	       break
	    end
	    i = i + 1
	 end
	 dirname = dirname + c
      end
      return dirname
   end
   private :parse257
end
