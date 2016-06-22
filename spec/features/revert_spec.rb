require "spec_helper"

describe "Reverting migrations" do
  around do |example|
    definition = <<~EOS
      CREATE OR REPLACE FUNCTION test() RETURNS text AS $$
      BEGIN
          RETURN 'test';
      END;
      $$ LANGUAGE plpgsql;
    EOS
    with_function_definition(name: :test, definition: definition) do
      example.run
    end
  end

  it "can run reversible migrations for creating functions" do
    migration = Class.new(ActiveRecord::Migration) do
      def change
        create_function :test
      end
    end

    expect { run_migration(migration, [:up, :down]) }.not_to raise_error
  end

  it "can run reversible migrations for dropping functions" do
    connection.create_function(:test)

    good_migration = Class.new(ActiveRecord::Migration) do
      def change
        drop_function :test, revert_to_version: 1
      end
    end
    bad_migration = Class.new(ActiveRecord::Migration) do
      def change
        drop_function :test
      end
    end

    expect { run_migration(good_migration, [:up, :down]) }.not_to raise_error
    expect { run_migration(bad_migration, [:up, :down]) }.
      to raise_error(
        ActiveRecord::IrreversibleMigration,
        /`create_function` is reversible only if given a `revert_to_version`/,
      )
  end
end