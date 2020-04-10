class ParameterError < StandardError
  def initialize(msg="Parameter error")
    super
  end
end

class DataError < StandardError
  def initialize(msg="Data Error")
    super
  end
end

class NotFoundError < StandardError
  def initialize(msg="Record not found")
    super
  end
end

class DeletedError < StandardError
  def initialize(msg="Deleted bib record")
    super
  end
end
