#' List languages from Google Translate API
#'
#' Returns a list of supported languages for translation.
#'
#' @param target If specified, language names are localized in target langauge
#'
#' @details
#' Supported language codes, generally consisting of its ISO 639-1 identifier. (E.g. \code{'en', 'ja'}).
#' In certain cases, BCP-47 codes including language + region identifiers are returned (e.g. \code{'zh-TW', 'zh-CH'})
#'
#' @return data.frame of supported languages
#' @seealso \url{https://cloud.google.com/translate/docs/reference/languages}
#'
#' @export
#' @family translations
gl_translate_list <- function(target = 'en'){

  assertthat::assert_that(is.character(target),
                          length(target) == 1)

  call_url <- sprintf("https://translation.googleapis.com/language/translate/v2/languages")

  f <- googleAuthR::gar_api_generator(call_url,
                                      "GET",
                                      pars_args = list(target = target),
                                      data_parse_function = function(x) x$data$languages)

  f()

}

#' Detect the language of text within a request
#'
#' @param string A character vector of text to detect language for
#' @param encode If TRUE, will run strings through URL encoding
#'
#' @return A list of the detected languages
#' @seealso \url{https://cloud.google.com/translate/docs/reference/detect}
#' @export
#' @family translations
gl_translate_detect <- function(string, encode = TRUE){

  if(encode){
    raw <- string
    string <- vapply(string,
                     utils::URLencode,
                     FUN.VALUE = character(1),
                     reserved = TRUE,
                     repeated = TRUE,
                     USE.NAMES = FALSE)
  }

  char_num <- sum(nchar(string))

  message("Detecting language: ",char_num," characters - ", substring(raw, 0, 50), "...")

  ## rate limits - 1000 requests per 100 seconds
  Sys.sleep(getOption("googleLanguageR.rate_limit"))

  ## character limits - 100000 characters per 100 seconds
  check_rate(sum(nchar(string)))

  call_url <- paste0("https://translation.googleapis.com/language/translate/v2/detect?",
                     paste0("q=", string, collapse = "&"))

  if(nchar(call_url) > 2000){
    stop("Total URL must be less than 2000 characters")
  }

  f <- googleAuthR::gar_api_generator(call_url,
                                      "POST",
                                      data_parse_function = function(x) x$data$detections)

  f()

}

.word_rate <- new.env(parent = globalenv())
.word_rate$characters <- 0
.word_rate$timestamp <- Sys.time()

# Limit the API to the limits imposed by Google
check_rate <- function(word_count,
                       .timestamp = Sys.time(),
                       character_limit = 100000L,
                       delay_limit = 100L){

  assertthat::assert_that(is.numeric(word_count),
                          length(word_count) == 1,
                          is.numeric(character_limit),
                          is.numeric(delay_limit),
                          assertthat::is.time(.timestamp))

  if(.word_rate$characters > 0){
    myMessage("# Current character batch: ", .word_rate$characters, level = 2)
  }

  .word_rate$characters <- .word_rate$characters + word_count
  if(.word_rate$characters > character_limit){
    myMessage("Limiting API as over ", character_limit," characters in ", delay_limit, " seconds", level = 3)
    myMessage("Timestamp batch start: ", .word_rate$timestamp, level = 2)

    delay <- difftime(.timestamp, .word_rate$timestamp, units = "secs")

    while(delay < delay_limit){
      myMessage("Waiting for ", format(round(delay_limit - delay), format = "%S"), level = 3)
      delay <- difftime(Sys.time(), .word_rate$timestamp, units = "secs")
      Sys.sleep(5)
    }

    myMessage("Ready to call API again", level = 2)
    .word_rate$characters <- 0
    .word_rate$timestamp <- Sys.time()

    }
}


#' Translate the language of text within a request
#'
#' @param string A character vector of text to detect language for
#' @param encode If TRUE, will run strings through URL encoding
#' @param target The target language
#' @param format Whether the text is plain or HTML
#' @param source Specify the language to translate from. Will detect it if left default
#' @param model What translation model to use
#'
#' @return A list of the detected languages
#' @seealso \url{https://cloud.google.com/translate/docs/reference/translate}
#' @export
#' @family translations
gl_translate_language <- function(string,
                                  encode = TRUE,
                                  target = "en",
                                  format = c("text","html"),
                                  source = '',
                                  model = c("nmt", "base")){

  assertthat::assert_that(is.character(string),
                          is.logical(encode),
                          is.character(target),
                          length(target) == 1,
                          is.character(source),
                          length(source) == 1)

  format <- match.arg(format)
  model <- match.arg(model)

  if(encode){
    raw <- string
    string <- vapply(string,
                     utils::URLencode,
                     FUN.VALUE = character(1),
                     reserved = TRUE,
                     repeated = TRUE,
                     USE.NAMES = FALSE)
  }

  char_num <- sum(nchar(string))

  myMessage("Translating: ",char_num," characters - ", substring(raw, 0, 50), "...", level = 3)

  if(length(string) > 1){
    myMessage("Translating vector of strings > 1: ", length(string), level = 2)
  }

  ## rate limits - 1000 requests per 100 seconds
  Sys.sleep(getOption("googleLanguageR.rate_limit"))

  ## character limits - 100000 characters per 100 seconds
  check_rate(char_num)

  call_url <- paste0("https://translation.googleapis.com/language/translate/v2")

  f <- googleAuthR::gar_api_generator(call_url,
                                      "POST",
                                      pars_args = list(target = target,
                                                       format = format,
                                                       source = source,
                                                       q = paste0(string, collapse = "&q=")),
                                      data_parse_function = function(x) x$data$translations)

  f()

}