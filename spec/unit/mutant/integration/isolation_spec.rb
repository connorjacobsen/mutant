RSpec.describe Mutant::Isolation::Fork, mutant: false do
  let(:object) { Mutant::Config::DEFAULT.isolation }

  it 'does isolate side effects' do
    initial = 1
    object.call { initial = 2  }
    expect(initial).to be(1)
  end

  it 'return block value' do
    expect(object.call { :foo }).to be(:foo)
  end

  it 'wraps exceptions' do
    expect { object.call { fail } }.to raise_error(
      Mutant::Isolation::Error,
      'marshal data too short'
    )
  end

  it 'wraps exceptions caused by crashing ruby' do
    expect do
      object.call do
        fail RbBug.call
      end
    end.to raise_error(Mutant::Isolation::Error)
  end

  it 'redirects $stderr of children to /dev/null' do
    begin
      Tempfile.open('mutant-test') do |file|
        $stderr = file
        object.call { $stderr.puts('test') }
        file.rewind
        expect(file.read).to eql('')
      end
    ensure
      $stderr = STDERR
    end
  end
end
