"use client"

import { cn } from "@/src/common"
import { useEffect, useState } from "react"
import { useFormikShadcnInput } from "./useFormik"
import { AppInput } from "../AppInput"

export function FormikInput(props: any) {
  const { field, meta, handleChange, hasError, isSuccess } =
    useFormikShadcnInput(props)

  const [open, setOpen] = useState(hasError)

  useEffect(() => {
    setOpen(hasError)
  }, [hasError])

  return (
    <div className="w-full">
      {/* <div className="relative w-full flex items-center"> */}
        <AppInput
          {...field}
          {...props}
          error={hasError}
          errorMessage={meta.error}
          aria-invalid={hasError}
          onChange={handleChange}
          className={cn(
            hasError && "border-destructive focus-visible:ring-destructive/30",
            isSuccess && "pr-9",
            props.className
          )}
        />

    </div>
  )
}
