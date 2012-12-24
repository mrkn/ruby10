#
#   thwait.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/18 03:13:14 $
#   	by Keiju ISHITSUKA(Nippon Rational Inc.)
#
# --
#
#   
#

require "thread.rb"
require "e2mmap.rb"

class ThreadsWait
  RCS_ID='-$Header: /home/keiju/var/src/var.lib/ruby/RCS/thwait.rb,v 1.1 1997/08/18 03:13:14 keiju Exp keiju $-'
  
  Exception2MessageMapper.extend_to(binding)
  def_exception("ErrWaitThreadsNothing", "Wait threads nothing.")
  def_exception("FinshedThreadsNothing", "finished thread nothing.")
  
  # class mthods
  #	all_waits
  
  #
  # ���ꤷ������åɤ����ƽ�λ����ޤ��Ԥ�. ���ƥ졼���Ȥ��ƸƤФ���
  # ���ꤷ������åɤ���λ����ȥ��ƥ졼����ƤӽФ�.
  #
  def ThreadsWait.all_waits(*threads)
    tw = ThreadsWait.new(th1, th2, th3, th4, th5)
    if iterator?
      tw.all_waits do
	|th|
	yield th
      end
    else
      tw.all_waits
    end
  end
  
  # initialize and terminating:
  #	initialize
  
  #
  # �����. �Ԥĥ���åɤλ��꤬�Ǥ���.
  #
  def initialize(*threads)
    @threads = []
    @wait_queue = Queue.new
    join_nowait(*threads) unless threads.empty?
  end
  
  # accessing
  #	threads
  
  # �Ԥ�����åɤΰ������֤�.
  attr :threads
  
  # testing
  #	empty?
  #	finished?
  #
  
  #
  # �Ԥ�����åɤ�¸�ߤ��뤫�ɤ������֤�.
  def empty?
    @threads.empty?
  end
  
  #
  # ���Ǥ˽�λ��������åɤ����뤫�ɤ����֤�
  def finished?
    !@wait_queue.empty?
  end
  
  # main process:
  #	join
  #	join_nowait
  #	next_wait
  #	all_wait
  
  #
  # �ԤäƤ��륹��åɤ��ɲä��Ԥ��ˤϤ���.
  #
  def join(*threads)
    join_nowait(*threads)
    next_wait
  end
  
  #
  # �ԤäƤ��륹��åɤ��ɲä���. �Ԥ��ˤ�����ʤ�.
  #
  def join_nowait(*threads)
    @threads.concat threads
    for th in threads
      Thread.start do
	th = Thread.join(th)
	@wait_queue.push th
      end
    end
  end
  
  #
  # �����Ԥ��ˤϤ���.
  # �ԤĤ٤�����åɤ��ʤ����, �㳰ErrWaitThreadsNothing ���֤�.
  # nonnlock�����λ��ˤ�, nonblocking��Ĵ�٤�. ¸�ߤ��ʤ����, �㳰
  # FinishedThreadNothing���֤�.
  #
  def next_wait(nonblock = nil)
    Threads.Wait.fail ErrWaitThreadsNothing if @threads.empty?
    
    th = @wait_queue.pop(nonblock)
    @threads.delete th
    th
  end
  
  #
  # ���ƤΥ���åɤ���λ����ޤ��Ԥ�. ���ƥ졼���Ȥ��ƸƤФ줿����, ��
  # ��åɤ���λ�����٤�, ���ƥ졼����ƤӽФ�.
  #
  def all_waits
    until @threads.empty?
      th = next_wait
      yield th if iterator?
    end
  end
end
