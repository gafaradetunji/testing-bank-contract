"use client"

import { useEffect, useState } from "react"
import { cn } from "@/src/common"
import { AlertCircle } from "lucide-react"
import { Input } from "./input"
import { Collapsible, CollapsibleContent } from "./collapsible"

export function AppInput({
  errorMessage,
  error,
  ...props
}) {
  const [open, setOpen] = useState(Boolean(error))

  // sync collapsible open state with error
  useEffect(() => {
    setOpen(Boolean(error))
  }, [error])

  return (
    <div className="w-full">
      <Input
        aria-invalid={error}
        {...props}
        className={cn(
          error && "border-destructive focus-visible:ring-destructive/30"
        )}
      />

      <Collapsible open={open} onOpenChange={setOpen}>
        <CollapsibleContent
          className={cn(
            "overflow-hidden text-sm text-destructive flex items-center gap-2 mt-1",
            open ? "slide-down" : "slide-up"
          )}
        >
          <AlertCircle className="size-4 text-destructive" />
          {errorMessage}
        </CollapsibleContent>
      </Collapsible>
    </div>
  )
}
