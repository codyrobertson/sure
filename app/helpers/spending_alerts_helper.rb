module SpendingAlertsHelper
  def alert_variant_classes(alert)
    case alert.severity.to_sym
    when :alert
      "bg-red-50 border-red-200 theme-dark:bg-red-900/20 theme-dark:border-red-800"
    when :warning
      "bg-yellow-50 border-yellow-200 theme-dark:bg-yellow-900/20 theme-dark:border-yellow-800"
    else
      "bg-blue-50 border-blue-200 theme-dark:bg-blue-900/20 theme-dark:border-blue-800"
    end
  end

  def alert_icon(alert)
    case alert.severity.to_sym
    when :alert
      "alert-circle"
    when :warning
      "alert-triangle"
    else
      "info"
    end
  end

  def alert_icon_color(alert)
    case alert.severity.to_sym
    when :alert
      "text-red-600 theme-dark:text-red-400"
    when :warning
      "text-yellow-600 theme-dark:text-yellow-400"
    else
      "text-blue-600 theme-dark:text-blue-400"
    end
  end
end
