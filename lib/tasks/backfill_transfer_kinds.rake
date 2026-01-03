namespace :transfers do
  desc "Backfill transaction kinds for existing transfers (cc_payment, loan_payment, funds_movement)"
  task backfill_kinds: :environment do
    puts "Backfilling transaction kinds for transfers..."

    updated_count = { cc_payment: 0, loan_payment: 0, funds_movement: 0 }
    skipped_count = 0

    Transfer.includes(
      inflow_transaction: { entry: :account },
      outflow_transaction: { entry: :account }
    ).find_each do |transfer|
      destination_account = transfer.to_account
      source_account = transfer.from_account

      unless destination_account && source_account
        skipped_count += 1
        next
      end

      # Determine the correct kind based on destination account
      correct_kind = Transfer.kind_for_account(destination_account)

      # Update outflow transaction (the "expense" side)
      outflow = transfer.outflow_transaction
      if outflow && outflow.kind != correct_kind
        outflow.update_column(:kind, correct_kind)
        updated_count[correct_kind.to_sym] += 1
        puts "  Updated: #{source_account.name} → #{destination_account.name} = #{correct_kind}"
      end

      # Inflow is always funds_movement
      inflow = transfer.inflow_transaction
      if inflow && inflow.kind != "funds_movement"
        inflow.update_column(:kind, "funds_movement")
      end
    end

    puts "\nBackfill complete!"
    puts "  Updated to cc_payment: #{updated_count[:cc_payment]}"
    puts "  Updated to loan_payment: #{updated_count[:loan_payment]}"
    puts "  Unchanged (funds_movement): #{updated_count[:funds_movement]}"
    puts "  Skipped (missing accounts): #{skipped_count}"
  end

  desc "Show current transfer kind distribution"
  task show_kinds: :environment do
    puts "Current transaction kind distribution:"
    counts = Transaction.group(:kind).count
    counts.each do |kind, count|
      puts "  #{kind}: #{count}"
    end

    puts "\nTransfers by destination account type:"
    Transfer.includes(inflow_transaction: { entry: :account }).find_each.group_by do |t|
      t.to_account&.accountable_type || "Unknown"
    end.each do |type, transfers|
      puts "  #{type}: #{transfers.count}"
    end
  end
end
