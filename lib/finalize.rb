#
#   finalize.rb - 
#   	$Release Version: $
#   	$Revision: 1.2 $
#   	$Date: 1997/07/25 02:43:00 $
#   	by Keiju ISHITSUKA(SHL Japan Inc.)
#
# --
#
#   Usage:
#
#   add(obj, dependant, method = :finalize, *opt)
#   add_dependency(obj, dependant, method = :finalize, *opt)
#	��¸�ط� R_method(obj, dependant) ���ɲ�
#
#   delete(obj_or_id, dependant, method = :finalize)
#   delete_dependency(obj_or_id, dependant, method = :finalize)
#	��¸�ط� R_method(obj, dependant) �κ��
#   delete_all_dependency(obj_or_id, dependant)
#	��¸�ط� R_*(obj, dependant) �κ��
#   delete_by_dependant(dependant, method = :finalize)
#	��¸�ط� R_method(*, dependant) �κ��
#   delete_all_by_dependant(dependant)
#	��¸�ط� R_*(*, dependant) �κ��
#   delete_all
#	���Ƥΰ�¸�ط��κ��.
#
#   finalize(obj_or_id, dependant, method = :finalize)
#   finalize_dependency(obj_or_id, dependant, method = :finalize)
#	��¸��Ϣ R_method(obj, dependtant) �Ƿ�Ф��dependant��
#	finalize����.
#   finalize_all_dependency(obj_or_id, dependant)
#	��¸��Ϣ R_*(obj, dependtant) �Ƿ�Ф��dependant��finalize����.
#   finalize_by_dependant(dependant, method = :finalize)
#	��¸��Ϣ R_method(*, dependtant) �Ƿ�Ф��dependant��finalize����.
#   fainalize_all_by_dependant(dependant)
#	��¸��Ϣ R_*(*, dependtant) �Ƿ�Ф��dependant��finalize����.
#   finalize_all
#	Finalizer����Ͽ��������Ƥ�dependant��finalize����
#
#   safe{..}
#	gc����Finalizer����ư����Τ�ߤ��.
#
#

module Finalizer
  RCS_ID='-$Header: /home/keiju/var/src/var.lib/ruby/RCS/finalize.rb,v 1.2 1997/07/25 02:43:00 keiju Exp keiju $-'
  
  # @dependency: {id => [[dependant, method, *opt], ...], ...}
  
  # ��¸�ط� R_method(obj, dependant) ���ɲ�
  def add_dependency(obj, dependant, method = :finalize, *opt)
    ObjectSpace.call_finalizer(obj)
    method = method.id unless method.kind_of?(Fixnum)
    assoc = [dependant, method].concat(opt)
    if dep = @dependency[obj.id]
      dep.push assoc
    else
      @dependency[obj.id] = [assoc]
    end
  end
  alias add add_dependency
  
  # ��¸�ط� R_method(obj, dependant) �κ��
  def delete_dependency(id, dependant, method = :finalize)
    id = id.id unless id.kind_of?(Fixnum)
    method = method.id unless method.kind_of?(Fixnum)
    for assoc in @dependency[id]
      assoc.delete_if do
	|d, m, *o|
	d == dependant && m == method
      end
      @dependency.delete(id) if assoc.empty?
    end
  end
  alias delete delete_dependency
  
  # ��¸�ط� R_*(obj, dependant) �κ��
  def delete_all_dependency(id, dependant)
    id = id.id unless id.kind_of?(Fixnum)
    method = method.id unless method.kind_of?(Fixnum)
    for assoc in @dependency[id]
      assoc.delete_if do
	|d, m, *o|
	d == dependant
      end
      @dependency.delete(id) if assoc.empty?
    end
  end
  
  # ��¸�ط� R_method(*, dependant) �κ��
  def delete_by_dependant(dependant, method = :finalize)
    method = method.id unless method.kind_of?(Fixnum)
    for id in @dependency.keys
      delete(id, dependant, method)
    end
  end
  
  # ��¸�ط� R_*(*, dependant) �κ��
  def delete_all_by_dependant(dependant)
    for id in @dependency.keys
      delete_all_dependency(id, dependant)
    end
  end
  
  # ��¸��Ϣ R_method(obj, dependtant) �Ƿ�Ф��dependant��finalize��
  # ��.
  def finalize_dependency(id, dependant, method = :finalize)
    id = id.id unless id.kind_of?(Fixnum)
    method = method.id unless method.kind_of?(Fixnum)
    for assocs in @dependency[id]
      assocs.delete_if do
	|d, m, *o|
	d.send(m, *o) if ret = d == dependant && m == method
	ret
      end
      @dependency.delete(id) if assoc.empty?
    end
  end
  alias finalize finalize_dependency
  
  # ��¸��Ϣ R_*(obj, dependtant) �Ƿ�Ф��dependant��finalize����.
  def finalize_all_dependency(id, dependant)
    id = id.id unless id.kind_of?(Fixnum)
    method = method.id unless method.kind_of?(Fixnum)
    for assoc in @dependency[id]
      assoc.delete_if do
	|d, m, *o|
	d.send(m, *o) if ret = d == dependant
      end
      @dependency.delete(id) if assoc.empty?
    end
  end
  
  # ��¸��Ϣ R_method(*, dependtant) �Ƿ�Ф��dependant��finalize����.
  def finalize_by_dependant(dependant, method = :finalize)
    method = method.id unless method.kind_of?(Fixnum)
    for id in @dependency.keys
      finalize(id, dependant, method)
    end
  end
  
  # ��¸��Ϣ R_*(*, dependtant) �Ƿ�Ф��dependant��finalize����.
  def fainalize_all_by_dependant(dependant)
    for id in @dependency.keys
      finalize_all_dependency(id, dependant)
    end
  end
  
  # Finalizer����Ͽ����Ƥ������Ƥ�dependant��finalize����
  def finalize_all
    for id, assocs in @dependency
      for dependant, method, *opt in assocs
	dependant.send(method, id, *opt)
      end
      assocs.clear
    end
  end
  
  # finalize_* ������˸ƤӽФ�����Υ��ƥ졼��
  def safe
    old_status = Thread.critical
    Thread.critical = TRUE
    ObjectSpace.remove_finalizer(@proc)
    yield
    ObjectSpace.add_finalizer(@proc)
    Thread.critical = old_status
  end
  
  # ObjectSpace#add_finalizer�ؤ���Ͽ�ؿ�
  def final_of(id)
    if assocs = @dependency.delete(id)
      for dependant, method, *opt in assocs
	dependant.send(method, id, *opt)
      end
    end
  end
  
  @dependency = Hash.new
  @proc = proc{|id| final_of(id)}
  ObjectSpace.add_finalizer(@proc)

  module_function :add
  module_function :add_dependency
  
  module_function :delete
  module_function :delete_dependency
  module_function :delete_all_dependency
  module_function :delete_by_dependant
  module_function :delete_all_by_dependant
  
  module_function :finalize
  module_function :finalize_dependency
  module_function :finalize_all_dependency
  module_function :finalize_by_dependant
  module_function :fainalize_all_by_dependant
  module_function :finalize_all

  module_function :safe
  
  module_function :final_of
  private_class_method :final_of
  
end

