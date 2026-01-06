require "test_helper"

class DetectSpendingAnomaliesJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "job runs without error for family with no transactions" do
    empty_family = families(:empty)
    assert_nothing_raised do
      DetectSpendingAnomaliesJob.perform_now(empty_family.id)
    end
  end

  test "job calls anomaly detector for family with transactions" do
    # Mock the AnomalyDetector to return empty analysis
    mock_analysis = {
      anomalies: [],
      new_merchants: [],
      summary: { anomaly_count: 0, alert_count: 0, warning_count: 0 }
    }

    mock_detector = mock("detector")
    mock_detector.expects(:analyze).returns(mock_analysis)

    Insights::AnomalyDetector.expects(:new).with(@family, period: anything).returns(mock_detector)

    assert_nothing_raised do
      DetectSpendingAnomaliesJob.perform_now(@family.id)
    end
  end

  test "job creates alerts when anomalies are detected" do
    category = categories(:food_and_drink)

    mock_analysis = {
      anomalies: [
        {
          category: { id: category.id, name: "Food & Drink", color: "#fd7f6f" },
          current: { amount: 500.0, formatted: "$500.00" },
          average: { amount: 200.0, formatted: "$200.00" },
          deviation_percent: 250.0,
          severity: :warning,
          top_transactions: []
        }
      ],
      new_merchants: [],
      summary: { anomaly_count: 1, alert_count: 0, warning_count: 1 }
    }

    mock_detector = mock("detector")
    mock_detector.expects(:analyze).returns(mock_analysis)

    Insights::AnomalyDetector.expects(:new).with(@family, period: anything).returns(mock_detector)

    # Clear existing alerts
    @family.spending_alerts.destroy_all

    assert_difference "SpendingAlert.count", 1 do
      DetectSpendingAnomaliesJob.perform_now(@family.id)
    end
  end

  test "job processes all families when no family_id provided" do
    # This tests that the job can be run without a family_id
    # We mock the AnomalyDetector for all families
    Insights::AnomalyDetector.stubs(:new).returns(
      stub(analyze: { anomalies: [], new_merchants: [] })
    )

    assert_nothing_raised do
      DetectSpendingAnomaliesJob.perform_now
    end
  end
end
