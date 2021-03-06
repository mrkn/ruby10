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
  # 指定したスレッドが全て終了するまで待つ. イテレータとして呼ばれると
  # 指定したスレッドが終了するとイテレータを呼び出す.
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
  # 初期化. 待つスレッドの指定ができる.
  #
  def initialize(*threads)
    @threads = []
    @wait_queue = Queue.new
    join_nowait(*threads) unless threads.empty?
  end
  
  # accessing
  #	threads
  
  # 待ちスレッドの一覧を返す.
  attr :threads
  
  # testing
  #	empty?
  #	finished?
  #
  
  #
  # 待ちスレッドが存在するかどうかを返す.
  def empty?
    @threads.empty?
  end
  
  #
  # すでに終了したスレッドがあるかどうか返す
  def finished?
    !@wait_queue.empty?
  end
  
  # main process:
  #	join
  #	join_nowait
  #	next_wait
  #	all_wait
  
  #
  # 待っているスレッドを追加し待ちにはいる.
  #
  def join(*threads)
    join_nowait(*threads)
    next_wait
  end
  
  #
  # 待っているスレッドを追加する. 待ちには入らない.
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
  # 次の待ちにはいる.
  # 待つべきスレッドがなければ, 例外ErrWaitThreadsNothing を返す.
  # nonnlockが真の時には, nonblockingで調べる. 存在しなければ, 例外
  # FinishedThreadNothingを返す.
  #
  def next_wait(nonblock = nil)
    Threads.Wait.fail ErrWaitThreadsNothing if @threads.empty?
    
    th = @wait_queue.pop(nonblock)
    @threads.delete th
    th
  end
  
  #
  # 全てのスレッドが終了するまで待つ. イテレータとして呼ばれた時は, ス
  # レッドが終了する度に, イテレータを呼び出す.
  #
  def all_waits
    until @threads.empty?
      th = next_wait
      yield th if iterator?
    end
  end
end
