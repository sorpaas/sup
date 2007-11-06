module Redwood

class Mode
  attr_accessor :buffer
  @@keymaps = {}

  def self.register_keymap keymap=nil, &b
    keymap = Keymap.new(&b) if keymap.nil?
    @@keymaps[self] = keymap
  end

  def initialize
    @buffer = nil
  end

  def self.make_name s; s.gsub(/.*::/, "").camel_to_hyphy; end
  def name; Mode.make_name self.class.name; end

  def self.load_all_modes dir
    Dir[File.join(dir, "*.rb")].each do |f|
      $stderr.puts "## loading mode #{f}"
      require f
    end
  end

  def killable?; true; end
  def draw; end
  def focus; end
  def blur; end
  def cancel_search!; end
  def in_search?; false end
  def status; ""; end
  def resize rows, cols; end
  def cleanup
    @buffer = nil
  end

  ## turns an input keystroke into an action symbol
  def resolve_input c
    ## try all keymaps in order of age
    action = nil
    klass = self.class

    ancestors.each do |klass|
      action = @@keymaps.member?(klass) && @@keymaps[klass].action_for(c)
      return action if action
    end

    nil
  end

  def handle_input c
    action = resolve_input(c) or return false
    send action
    true
  end

  def help_text
    used_keys = {}
    ancestors.map do |klass|
      km = @@keymaps[klass] or next
      title = "Keybindings from #{Mode.make_name klass.name}"
      s = <<EOS
#{title}
#{'-' * title.length}

#{km.help_text used_keys}
EOS
      begin
        used_keys.merge! km.keysyms.to_boolean_h
      rescue ArgumentError
        raise km.keysyms.inspect
      end
      s
    end.compact.join "\n"
  end

  ## helper function
  def save_to_file fn
    if File.exists? fn
      return unless BufferManager.ask_yes_or_no "File exists. Overwrite?"
    end
    begin
      File.open(fn, "w") { |f| yield f }
      BufferManager.flash "Successfully wrote #{fn}."
    rescue SystemCallError, IOError => e
      BufferManager.flash "Error writing to file: #{e.message}"
    end
  end
end

end
