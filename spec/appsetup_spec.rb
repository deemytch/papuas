#!/usr/bin/ruby
# Проверка утилиты управления данными в базе

Config.start(:appsetup)

RSpec.describe 'appsetup' do
	# before(:each){ truncate_tables }
	# after(:each){ truncate_tables }
	context 'добавление записей' do
		it 'TaskNode' do
			ret = system %{../appsetup.rb --verbose debug -N noda1 -a -n localhost -u #$USER -p6677 }
			expect(ret).to eq true
			expect(TaskNode.count).to eq 1
		end
		it 'SourceNode'
		it 'пользвателя к TaskNode'
		it 'пользователя к SourceNode'
	end
	context 'удаление записей' do
		it 'TaskNode'
		it 'SourceNode'
		it 'User'
	end
	context 'изменение записей' do
		it 'TaskNode'
		it 'SourceNode'
		it 'User'
	end
end
